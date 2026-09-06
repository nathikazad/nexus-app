import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_books/companion/reading_companion.dart';
import 'package:nx_books/companion/reading_companion_controller.dart';
import 'package:nx_voice/nx_voice.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Session session;
  late _Microphone mic;
  late ReadingCompanionController controller;
  setUp(() {
    session = _Session();
    mic = _Microphone();
    controller = ReadingCompanionController(
      config: DocumentAiSessionConfig(
        socketUrl: 'ws://test',
        userId: '1',
        documentId: 7,
        authHeaders: (_) async => {},
      ),
      session: session,
      microphone: mic,
      player: _Player(),
    );
  });
  tearDown(() => controller.dispose());

  test('text uses selected context and merges streaming/final transcripts', () async {
    expect(await controller.send('Explain', selection: 'A passage'), true);
    expect(session.sent.single, contains('A passage'));
    expect(controller.messages.single.text, 'Explain');
    controller.receive(
      '{"type":"transcript-delta","role":"assistant","text":"Hello","turnkey":"a"}',
      '1',
    );
    controller.receive(
      '{"type":"transcript-delta","role":"assistant","text":" there","turnkey":"a"}',
      '1',
    );
    controller.receive(
      '{"type":"transcript","role":"assistant","text":"Hello there","turnkey":"a"}',
      '1',
    );
    expect(controller.messages.length, 2);
    expect(controller.messages.last.text, 'Hello there');
    await controller.cancel();
    controller.receive('late response', '2');
    expect(controller.messages.length, 2);
  });

  test('release during connection never starts microphone', () async {
    session.gate = Completer<void>();
    final starting = controller.startRecording();
    await Future<void>.delayed(Duration.zero);
    await controller.stopRecording();
    session.gate!.complete();
    await starting;
    expect(mic.starts, 0);
    expect(controller.recording, false);
  });

  test('voice starts one turn and release sends EOF once', () async {
    await controller.startRecording();
    expect(controller.recording, true);
    await controller.stopRecording();
    await controller.stopRecording();
    expect(session.audioStarts, 1);
    expect(session.audioEnds, 1);
  });

  testWidgets('tablet button opens and closes companion with keyboard inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ReadingCompanion(child: Scaffold(body: Text('Bookshelf'))),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Reading companion'));
    await tester.pumpAndSettle();
    expect(
      find.text('Open a book or chapter to discuss it here.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Close companion'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Reading companion'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Session extends DocumentAiSession {
  Completer<void>? gate;
  final sent = <String>[];
  var audioStarts = 0;
  var audioEnds = 0;
  @override
  Future<void> connect(DocumentAiSessionConfig config) async {
    await gate?.future;
  }

  @override
  void sendTextTurn(String text) {
    sent.add(text);
  }

  @override
  void beginAudioTurn() {
    audioStarts++;
  }

  @override
  void endAudioTurn() {
    audioEnds++;
  }

  @override
  Future<void> disconnect() async {}
}

class _Microphone extends NxMicrophoneOpusStreamer {
  var starts = 0;
  @override
  Future<bool> start({
    required FutureOr<void> Function(Uint8List) onOpusPacket,
    void Function(Object)? onError,
  }) async {
    starts++;
    return true;
  }

  @override
  Future<List<Uint8List>> stop({bool flushRemainder = true}) async => [];
  @override
  Future<void> dispose() async {}
}

class _Player extends NxWavAudioPlayer {
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}
