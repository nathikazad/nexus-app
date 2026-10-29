import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_voice/nx_voice.dart';
import 'package:nx_expense/features/ai/expense_assistant_page.dart';

class _Auth extends AuthController {
  @override
  Future<User?> build() async =>
      User(userId: '1', preset: BackendPreset.localhost, domainId: 1);
}

class _Session extends DocumentAiSession {
  void Function(NxVoiceTextChunk)? chunk;
  void Function(NxVoiceTextEof)? eof;
  int sent = 0;
  bool started = false;
  @override
  set onTextChunk(void Function(NxVoiceTextChunk)? value) => chunk = value;
  @override
  set onTextEof(void Function(NxVoiceTextEof)? value) => eof = value;
  @override
  Future<void> connect(DocumentAiSessionConfig config) async {}
  @override
  void beginAudioTurn({String context = '', bool preserveContext = false}) {
    started = true;
  }

  @override
  void endAudioTurn() {
    sent++;
  }

  @override
  Future<void> disconnect() async {}
}

class _Mic extends NxMicrophoneOpusStreamer {
  bool recording = false;
  @override
  Future<bool> ensurePermission() async => true;
  @override
  Future<bool> start({
    required FutureOr<void> Function(Uint8List) onOpusPacket,
    void Function(Object)? onError,
  }) async {
    recording = true;
    return true;
  }

  @override
  Future<List<Uint8List>> stop({bool flushRemainder = true}) async {
    recording = false;
    return [];
  }

  @override
  Future<void> dispose() async {
    recording = false;
  }
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Overlay readable in ${brightness.name} on small screens', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var stopped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: ExpenseCaptureView(
            domain: 'Home',
            phase: ExpenseVoicePhase.listening,
            transcript: 'Coffee and lunch, about 20',
            onStop: () => stopped = true,
            onClose: () {},
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('Coffee and lunch, about 20'));
      final scheme = Theme.of(
        tester.element(find.text('Coffee and lunch, about 20')),
      ).colorScheme;
      expect(scheme.brightness, brightness);
      final a = text.style!.color!.computeLuminance();
      final b = scheme.surfaceContainerHighest.computeLuminance();
      expect(
        ((a > b ? a : b) + .05) / ((a > b ? b : a) + .05),
        greaterThanOrEqualTo(4.5),
      );
      await tester.tap(find.byTooltip('Stop and send'));
      expect(stopped, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Auto listens, previews, stops once, replies and dismisses', (
    tester,
  ) async {
    final session = _Session();
    final mic = _Mic();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          expenseVoiceSessionProvider.overrideWithValue(() => session),
          expenseMicrophoneProvider.overrideWithValue(() => mic),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showExpenseAssistant(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await ProviderScope.containerOf(
      tester.element(find.text('Open')),
    ).read(authProvider.future);
    await tester.pump();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(session.started, isTrue);
    expect(mic.recording, isTrue);
    session.chunk!(
      NxVoiceTextChunk(
        text: '{"type":"transcript","role":"user","text":"Lunch for 20"}',
        streamIndex: 1,
      ),
    );
    await tester.pump();
    expect(find.text('Lunch for 20'), findsOneWidget);
    await tester.tap(find.byTooltip('Stop and send'));
    await tester.pump();
    expect(session.sent, 1);
    expect(mic.recording, isFalse);
    session.chunk!(
      NxVoiceTextChunk(
        text:
            '{"type":"transcript","role":"assistant","text":"Saved your note."}',
        streamIndex: 1,
      ),
    );
    session.eof!(NxVoiceTextEof(streamIndex: 1));
    await tester.pump();
    expect(find.text('Saved your note.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Tell AI'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
