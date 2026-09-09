import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_books/companion/reading_companion.dart';
import 'package:nx_books/companion/reading_companion_controller.dart';
import 'package:nx_documents/nx_documents.dart';
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
    );
  });
  tearDown(() => controller.dispose());
  test(
    'offline questions and recording are rejected without sending',
    () async {
      final offline = ReadingCompanionController(
        config: controller.config,
        session: session,
        microphone: mic,
        hasNetwork: () async => false,
      );
      expect(await offline.send('Keep this question'), isFalse);
      expect(offline.error, contains('require internet'));
      expect(offline.busy, isFalse);
      expect(session.sent, isEmpty);
      await offline.startRecording();
      expect(offline.recording, isFalse);
      expect(session.audioStarts, 0);
      offline.dispose();
    },
  );

  testWidgets('question field keeps deletions when typing resumes', (
    tester,
  ) async {
    final input = TextEditingController();
    addTearDown(input.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ReadingQuestionField(controller: input)),
      ),
    );
    await tester.showKeyboard(find.byType(ReadingQuestionField));
    final configuration = tester.testTextInput.setClientArgs!;
    expect(configuration['autocorrect'], false);
    expect(configuration['enableSuggestions'], false);
    await tester.enterText(
      find.byType(ReadingQuestionField),
      'explain benefit',
    );
    await tester.enterText(find.byType(ReadingQuestionField), 'explain');
    await tester.pump();
    await tester.enterText(find.byType(ReadingQuestionField), 'explain scale');
    expect(input.text, 'explain scale');
    expect(input.text, isNot(contains('benefit')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('question clear button clears text and dismisses keyboard', (
    tester,
  ) async {
    final input = TextEditingController(text: 'remove me');
    final focus = FocusNode();
    addTearDown(input.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReadingQuestionField(controller: input, focusNode: focus),
        ),
      ),
    );
    await tester.showKeyboard(find.byType(ReadingQuestionField));
    expect(focus.hasFocus, isTrue);
    await tester.tap(find.byTooltip('Clear question and dismiss keyboard'));
    await tester.pump();
    expect(input.text, isEmpty);
    expect(focus.hasFocus, isFalse);
    expect(tester.takeException(), isNull);
  });

  test('text uses selected context and merges streaming/final transcripts', () async {
    expect(await controller.send('Explain', selection: 'A passage'), true);
    expect(
      session.sent.single,
      'Selected passage (reference text):\n"A passage"\n\nQuestion: Explain',
    );
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

  test('cancel during connection never starts microphone', () async {
    session.gate = Completer<void>();
    final starting = controller.startRecording();
    await Future<void>.delayed(Duration.zero);
    await controller.cancel();
    session.gate!.complete();
    await starting;
    expect(mic.starts, 0);
    expect(controller.recording, false);
  });

  test(
    'clear waits for database and retains local history on failure',
    () async {
      controller.messages.add(
        const ReadingMessage('assistant', 'Saved answer'),
      );
      expect(
        await controller.clearTranscript(
          () async => throw StateError('offline'),
        ),
        false,
      );
      expect(controller.messages.single.text, 'Saved answer');
      final saved = Completer<void>();
      final clearing = controller.clearTranscript(() => saved.future);
      await Future<void>.delayed(Duration.zero);
      expect(controller.messages, hasLength(1));
      expect(controller.busy, true);
      saved.complete();
      expect(await clearing, true);
      expect(controller.messages, isEmpty);
      controller.receive('late reply', '0');
      expect(controller.messages, isEmpty);
    },
  );

  test('stream keeps whitespace and final replaces tokens across turns', () async {
    await controller.send('First');
    for (final token in [
      '# Title',
      '\n\n',
      'Amazon',
      ' ',
      'Web',
      ' ',
      'Services',
    ]) {
      controller.receive(token, '0');
    }
    expect(controller.messages.last.text, '# Title\n\nAmazon Web Services');
    controller.receive(
      '{"type":"transcript","role":"assistant","text":"# Title\\n\\nAmazon Web Services","turnkey":"3:6"}',
      '0',
    );
    expect(controller.messages.length, 2);
    controller.busy = false;
    await controller.send('Second');
    controller.receive('New answer', '0');
    controller.receive(
      '{"type":"transcript","role":"assistant","text":"New answer","turnkey":"3:7"}',
      '0',
    );
    expect(controller.messages.length, 4);
    expect(controller.messages[1].text, '# Title\n\nAmazon Web Services');
    expect(controller.messages.last.text, 'New answer');
  });

  test('voice starts one turn and stop sends EOF once', () async {
    await controller.startRecording();
    expect(controller.recording, true);
    await controller.stopRecording();
    await controller.stopRecording();
    expect(session.audioStarts, 1);
    expect(session.audioEnds, 1);
  });

  test('server error ends waiting and stays out of the transcript', () async {
    await controller.send('question');
    controller.receive('{"type":"error","message":"Please try again."}', '1');
    expect(controller.busy, false);
    expect(controller.error, 'Please try again.');
    expect(controller.messages.length, 1);
  });

  testWidgets('tap starts recording and stop sends only once', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (context, _) =>
                ReadingMicrophoneButton(controller: controller),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Record a question'));
    await tester.pump();
    expect(mic.starts, 1);
    expect(controller.recording, true);
    expect(find.byIcon(Icons.stop_circle), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(controller.recording, true);
    await tester.tap(find.byTooltip('Stop recording and send'));
    await tester.pump();
    expect(controller.recording, false);
    expect(session.audioEnds, 1);
    await tester.tap(find.byTooltip('Record a question'));
    expect(mic.starts, 1); // Disabled while waiting for a reply.
    controller.receive(
      '{"type":"transcript","role":"assistant","text":"Answer","turnkey":"voice"}',
      '1',
    );
    expect(controller.messages.last.text, 'Answer');
    await controller.cancel();
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

  testWidgets('AI selection request opens companion with attached passage', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    const identity = DocumentIdentity(id: 7, modelType: 'Book');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ReadingCompanion(
            identity: identity,
            child: Scaffold(body: Text('Book')),
          ),
        ),
      ),
    );

    container.read(readingSelectionProvider).value =
        const ReadingSelectionRequest(identity, 'Selected book sentence');
    await tester.pump();

    expect(find.text('Selected book sentence'), findsOneWidget);
    expect(find.textContaining('Selected passage'), findsOneWidget);
    expect(
      find.text('Open a book or chapter to discuss it here.'),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('popup selects any of the five layouts', (tester) async {
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
    final panel = find.byKey(const ValueKey('reading-companion-panel'));
    final compact = tester.getSize(panel);
    expect(compact, const Size(400, 540));

    await tester.tap(find.byTooltip('Change panel layout'));
    await tester.pumpAndSettle();
    final layoutButton = tester.getRect(
      find.byKey(const ValueKey('panel-layout-button-anchor')),
    );
    final picker = tester.getRect(
      find.byKey(const ValueKey('panel-layout-picker')),
    );
    expect(picker.right, closeTo(layoutButton.right, 1));
    expect(picker.top, closeTo(layoutButton.bottom, 1));
    expect(picker.width, greaterThan(picker.height * 4));
    expect(find.byType(PanelLayoutIcon), findsNWidgets(6));
    await tester.tap(find.byTooltip('Expanded panel'));
    await tester.pump();
    expect(tester.getSize(panel), const Size(560, 760));

    await tester.tap(find.byTooltip('Change panel layout'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Full-width bottom panel'));
    await tester.pump();
    final bottom = tester.getSize(panel);
    expect(bottom.width, 800);
    expect(bottom.height, lessThan(1100));

    await tester.tap(find.byTooltip('Change panel layout'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Full-height right panel'));
    await tester.pump();
    expect(tester.getSize(panel), const Size(560, 1100));

    await tester.tap(find.byTooltip('Change panel layout'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Full-screen panel'));
    await tester.pump();
    expect(tester.getSize(panel), const Size(800, 1100));

    await tester.tap(find.byTooltip('Change panel layout'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Compact panel'));
    await tester.pump();
    expect(tester.getSize(panel), compact);
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
