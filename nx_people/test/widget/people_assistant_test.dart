import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_people/data/auth/people_auth_controller.dart';
import 'package:nx_people/features/assistant/people_assistant.dart';
import 'package:nx_voice/nx_voice.dart';

class FakeSession extends DocumentAiSession {
  DocumentAiSessionConfig? config;
  String? sent;
  String? context;
  bool disconnected = false;
  int starts = 0;
  int ends = 0;
  Completer<void>? connecting;
  bool failConnect = false;
  @override
  void beginAudioTurn({String context = '', bool preserveContext = false}) {
    starts++;
    this.context = context;
  }

  @override
  void endAudioTurn() {
    ends++;
  }

  @override
  void sendAudioPacket(Uint8List packet) {}

  void Function(NxVoiceTextChunk)? receive;
  void Function(NxVoiceTextEof)? eof;
  @override
  set onTextChunk(void Function(NxVoiceTextChunk)? value) => receive = value;
  @override
  set onTextEof(void Function(NxVoiceTextEof)? value) => eof = value;
  @override
  Future<void> connect(DocumentAiSessionConfig value) async {
    if (failConnect) throw StateError("Socket rejected");
    config = value;
    await connecting?.future;
  }

  @override
  void sendTextTurn(
    String text, {
    String context = '',
    bool preserveContext = false,
  }) {
    sent = text;
    this.context = context;
  }

  @override
  Future<void> disconnect() async {
    disconnected = true;
  }
}

class FakeMic extends NxMicrophoneOpusStreamer {
  @override
  Future<bool> ensurePermission() async => permission;
  bool permission = true;
  int starts = 0;
  int stops = 0;
  bool disposed = false;
  @override
  Future<bool> start({
    required FutureOr<void> Function(Uint8List) onOpusPacket,
    void Function(Object)? onError,
  }) async {
    starts++;
    return true;
  }

  @override
  Future<List<Uint8List>> stop({bool flushRemainder = true}) async {
    stops++;
    return [];
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

Widget harness(FakeSession session, FakeMic mic) => ProviderScope(
  overrides: [
    authProvider.overrideWith(
      () => PeopleAuthController(
        initialUser: User(
          userId: '1',
          domainId: 1,
          preset: BackendPreset.defaultPreset,
        ),
      ),
    ),
    peopleAiSessionFactoryProvider.overrideWithValue(() => session),
    peopleMicrophoneFactoryProvider.overrideWithValue(() => mic),
  ],
  child: const MaterialApp(
    home: Scaffold(
      body: Text('Profile remains visible'),
      floatingActionButton: PeopleAssistantButton(),
    ),
  ),
);

void main() {
  testWidgets(
    'connection errors are not labeled permission failures and hold can retry',
    (tester) async {
      final session = FakeSession()..failConnect = true;
      final mic = FakeMic();
      await tester.pumpWidget(harness(session, mic));
      await tester.pumpAndSettle();
      Future<void> hold() async {
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(PeopleAssistantButton)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Keep holding to record…'), findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
        await gesture.up();
        await tester.pump();
      }

      await hold();
      expect(
        find.text('Could not connect to the assistant. Please retry.'),
        findsOneWidget,
      );
      expect(mic.starts, 0);
      session.failConnect = false;
      await hold();
      expect(mic.starts, 1);
      expect(session.ends, 1);
      session.eof!(const NxVoiceTextEof(streamIndex: 1));
      await tester.pump();
      await tester.tap(find.byTooltip('Close assistant'));
      await tester.pump();
    },
  );
  testWidgets('denied microphone permission never sends an audio turn', (
    tester,
  ) async {
    final session = FakeSession();
    final mic = FakeMic()..permission = false;
    await tester.pumpWidget(harness(session, mic));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PeopleAssistantButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Record voice'));
    await tester.pump();
    expect(
      find.textContaining('Microphone permission is required'),
      findsOneWidget,
    );
    expect(session.starts, 0);
    expect(mic.starts, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'two second hold records and release shows reply over current page',
    (tester) async {
      final session = FakeSession();
      final mic = FakeMic();
      await tester.pumpWidget(harness(session, mic));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PeopleAssistantButton)),
      );
      await tester.pump(const Duration(milliseconds: 1900));
      expect(mic.starts, 0);
      await tester.pump(const Duration(milliseconds: 101));
      await tester.pump();
      expect(mic.starts, 1);
      expect(session.starts, 1);
      expect(find.text('Profile remains visible'), findsOneWidget);
      await gesture.up();
      await tester.pump();
      expect(mic.stops, 1);
      expect(session.ends, 1);
      session.receive!(
        NxVoiceTextChunk(
          text: jsonEncode({
            'type': 'transcript',
            'role': 'assistant',
            'text': 'Saved the note.',
          }),
          streamIndex: 1,
        ),
      );
      session.eof!(const NxVoiceTextEof(streamIndex: 1));
      await tester.pump();
      expect(find.text('Saved the note.'), findsOneWidget);
      await tester.tap(find.byTooltip('Close assistant'));
      await tester.pump();
      expect(mic.disposed, true);
    },
  );
  testWidgets('release while connecting cancels microphone startup', (
    tester,
  ) async {
    final session = FakeSession()..connecting = Completer<void>();
    final mic = FakeMic();
    await tester.pumpWidget(harness(session, mic));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PeopleAssistantButton)),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    session.connecting!.complete();
    await tester.pump();
    expect(mic.starts, 0);
    expect(session.starts, 0);
    await tester.tap(find.byTooltip('Close assistant'));
    await tester.pump();
  });
  testWidgets('chat mic toggles recording and sending', (tester) async {
    final session = FakeSession();
    final mic = FakeMic();
    await tester.pumpWidget(harness(session, mic));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PeopleAssistantButton));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Attach image'), findsOneWidget);
    await tester.tap(find.byTooltip('Record voice'));
    await tester.pump();
    expect(mic.starts, 1);
    await tester.tap(find.byTooltip('Stop recording'));
    await tester.pump();
    expect(session.ends, 1);
    expect(mic.stops, 1);
    session.eof!(const NxVoiceTextEof(streamIndex: 1));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
  });

  for (final selection in <PeopleAssistantContext?>[
    null,
    const PeopleAssistantContext(kind: 'Person', id: 42, name: 'Dave'),
    const PeopleAssistantContext(
      kind: 'Meet',
      id: 81,
      name: 'Conversation with Dave',
    ),
  ]) {
    testWidgets(
      'AI entry point preserves ${selection?.kind ?? 'general'} context',
      (tester) async {
        final session = FakeSession();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(
                () => PeopleAuthController(
                  initialUser: User(
                    userId: '1',
                    domainId: 1,
                    preset: BackendPreset.defaultPreset,
                  ),
                ),
              ),
              peopleAiSessionFactoryProvider.overrideWithValue(() => session),
            ],
            child: MaterialApp(
              home: Scaffold(
                floatingActionButton: PeopleAssistantButton(
                  selection: selection,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PeopleAssistantButton));
        await tester.pumpAndSettle();
        expect(
          find.text(selection?.name ?? 'People assistant'),
          findsOneWidget,
        );
        await tester.enterText(find.byType(TextField), 'Add this email');
        await tester.tap(find.byTooltip('Send message'));
        await tester.pump();
        expect(session.sent, 'Add this email');
        expect(session.config!.clientId, 'nx_people');
        expect(session.config!.domainId, 1);
        final selected = jsonDecode(session.context!)['selected_record'];
        expect(
          selected,
          selection == null
              ? null
              : {
                  'model_type': selection.kind,
                  'id': selection.id,
                  'name': selection.name,
                },
        );
        // A queued turn disables duplicate submission.
        expect(
          tester
              .widget<IconButton>(
                find.widgetWithIcon(IconButton, Icons.send_rounded),
              )
              .onPressed,
          isNull,
        );
        session.receive!(
          const NxVoiceTextChunk(
            text:
                '{"type":"transcript-delta","role":"assistant","text":"Email "}',
            streamIndex: 1,
          ),
        );
        session.receive!(
          const NxVoiceTextChunk(
            text:
                '{"type":"transcript-delta","role":"assistant","text":"added"}',
            streamIndex: 1,
          ),
        );
        session.receive!(
          const NxVoiceTextChunk(
            text:
                '{"type":"transcript","role":"assistant","text":"Email added."}',
            streamIndex: 1,
          ),
        );
        session.eof!(const NxVoiceTextEof(streamIndex: 1));
        await tester.pumpAndSettle();
        expect(find.text('Email added.'), findsOneWidget);
        expect(find.text('Email addedEmail added.'), findsNothing);
        expect(
          tester
              .widget<IconButton>(
                find.widgetWithIcon(IconButton, Icons.send_rounded),
              )
              .onPressed,
          isNotNull,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(session.disconnected, isTrue);
      },
    );
  }
}
