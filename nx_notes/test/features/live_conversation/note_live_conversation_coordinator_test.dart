import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_live_agent/nx_live_agent.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/features/companion/note_companion.dart';
import 'package:nx_notes/features/live_conversation/note_live_conversation_controller.dart';
import 'package:nx_notes/features/live_conversation/note_live_conversation_coordinator.dart';
import 'package:nx_notes/features/live_conversation/note_live_conversation_screen.dart';

class _FakeTransport
    implements
        LiveAgentTransport,
        LiveAgentInputControlTransport,
        LiveAgentPlaybackControlTransport {
  final eventsController = StreamController<LiveAgentEvent>.broadcast();
  int closeRequests = 0;
  int cancelRequests = 0;
  final inputEnabledValues = <bool>[];
  final automaticVadValues = <bool>[];
  final playbackPausedValues = <bool>[];
  int clearInputRequests = 0;
  int commitInputRequests = 0;
  int responseRequests = 0;

  @override
  Stream<LiveAgentEvent> get events => eventsController.stream;

  @override
  Future<void> connect({
    required String credential,
    required LiveAgentSpec spec,
    required List<LiveAgentToolDefinition> tools,
  }) async {
    eventsController.add(const LiveAgentEvent(LiveAgentEventType.connected));
  }

  @override
  Future<void> cancelResponse() async => cancelRequests += 1;

  @override
  Future<void> close() async => closeRequests += 1;

  @override
  Future<void> discardConversation({
    Set<String> keepItemIds = const {},
  }) async {}

  @override
  Future<void> dispose() async {
    if (!eventsController.isClosed) await eventsController.close();
  }

  @override
  Future<void> requestResponse() async => responseRequests += 1;

  @override
  Future<void> sendInstruction(
    String text, {
    bool requestResponse = true,
  }) async {}

  @override
  Future<void> sendToolResult(String callId, Object? output) async {}

  @override
  Future<void> setAutomaticTurnDetection(bool enabled) async =>
      automaticVadValues.add(enabled);

  @override
  Future<void> clearInputAudio() async => clearInputRequests += 1;

  @override
  Future<void> commitInputAudio() async => commitInputRequests += 1;

  @override
  Future<void> setInputEnabled(bool enabled) async =>
      inputEnabledValues.add(enabled);

  @override
  Future<void> setPlaybackPaused(bool paused) async =>
      playbackPausedValues.add(paused);
}

void main() {
  test('keeps one frozen conversation until its recap is dismissed', () async {
    final transport = _FakeTransport();
    var controllerCreations = 0;
    final coordinator = NoteLiveConversationCoordinator(
      createController: () {
        controllerCreations += 1;
        return NoteLiveConversationController(
          session: LiveAgentSession(transport: transport),
        );
      },
      credentialProvider: const StaticLiveAgentCredentialProvider('test-key'),
    );

    expect(
      await coordinator.start(document: _document(1, 'Source book')),
      true,
    );
    await pumpEventQueue();
    expect(coordinator.isActive, true);

    expect(await coordinator.start(document: _document(2, 'Chapter')), false);
    expect(controllerCreations, 1);
    expect(coordinator.sourceDocument?.id, 1);

    await coordinator.stop();
    expect(transport.closeRequests, 1);
    expect(coordinator.hasRecap, true);
    expect(await coordinator.start(document: _document(2, 'Chapter')), false);

    coordinator.dismissRecap();
    expect(coordinator.hasConversation, false);
    coordinator.dispose();
  });

  testWidgets(
    'shows the same Mac live controls after navigating to another document',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final transport = _FakeTransport();
      final coordinator = NoteLiveConversationCoordinator(
        createController: () => NoteLiveConversationController(
          session: LiveAgentSession(transport: transport),
        ),
        credentialProvider: const StaticLiveAgentCredentialProvider('test-key'),
      );
      addTearDown(coordinator.dispose);
      await coordinator.start(document: _document(1, 'Source book'));

      Widget appFor(NxDocument document) => ProviderScope(
        overrides: [
          userIdProvider.overrideWithValue(null),
          sockWsUrlProvider.overrideWithValue(null),
          imageBaseUrlProvider.overrideWithValue(null),
          noteLiveConversationCoordinatorProvider.overrideWithValue(
            coordinator,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: NoteCompanion(document: document),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpWidget(appFor(_document(1, 'Source book')));
      expect(find.byTooltip('Stop live conversation'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('mac-live-conversation-controls')),
        findsOneWidget,
      );
      expect(find.byTooltip('Pause live playback'), findsOneWidget);
      expect(find.byTooltip('Mute microphone'), findsOneWidget);
      expect(find.byTooltip('Turn off automatic VAD'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
      expect(find.byIcon(Icons.headphones_rounded), findsNothing);

      await tester.tap(find.byTooltip('Pause live playback'));
      await tester.pump();
      expect(transport.playbackPausedValues, [true]);
      expect(transport.inputEnabledValues, [false]);
      expect(find.byTooltip('Resume live playback'), findsOneWidget);

      await tester.tap(find.byTooltip('Resume live playback'));
      await tester.pump();
      expect(transport.playbackPausedValues, [true, false]);
      expect(transport.inputEnabledValues, [false, true]);

      transport.eventsController.add(
        const LiveAgentEvent(LiveAgentEventType.speaking),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Mute microphone'));
      await tester.pump();
      expect(transport.inputEnabledValues, [false, true, false]);
      expect(coordinator.controller?.phase, LiveAgentPhase.speaking);
      expect(transport.cancelRequests, 0);
      expect(find.byTooltip('Unmute microphone'), findsOneWidget);

      await tester.tap(find.byTooltip('Unmute microphone'));
      await tester.pump();
      expect(transport.inputEnabledValues, [false, true, false, true]);

      await tester.tap(find.byTooltip('Turn off automatic VAD'));
      await tester.pump();
      expect(transport.automaticVadValues, [false]);
      expect(transport.cancelRequests, 0);
      expect(find.byTooltip('Turn on automatic VAD'), findsOneWidget);
      expect(find.byTooltip('Start recording'), findsOneWidget);

      await tester.tap(find.byTooltip('Start recording'));
      await tester.pump();
      expect(find.byTooltip('Send recording'), findsOneWidget);

      await tester.tap(find.byTooltip('Send recording'));
      await tester.pump();
      expect(transport.commitInputRequests, 1);
      expect(transport.responseRequests, 1);
      expect(transport.automaticVadValues, [false]);
      expect(find.byTooltip('Start recording'), findsOneWidget);

      await tester.tap(find.byTooltip('Turn on automatic VAD'));
      await tester.pump();
      expect(transport.automaticVadValues, [false, true]);
      expect(find.byTooltip('Turn off automatic VAD'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('note-companion-chat-panel')),
        findsNothing,
      );

      await tester.pumpWidget(appFor(_document(2, 'Chapter')));
      await tester.pump();
      expect(find.byTooltip('Stop live conversation'), findsOneWidget);
      expect(coordinator.sourceDocument?.title, 'Source book');

      final stopButton = tester.widget<FloatingActionButton>(
        find.ancestor(
          of: find.byIcon(Icons.stop_rounded),
          matching: find.byType(FloatingActionButton),
        ),
      );
      stopButton.onPressed!();
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 300));

      expect(transport.closeRequests, 1);
      expect(find.text('Conversation ended'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('shows iPhone mute and stop in a compact bottom bar', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final transport = _FakeTransport();
    final coordinator = NoteLiveConversationCoordinator(
      createController: () => NoteLiveConversationController(
        session: LiveAgentSession(transport: transport),
      ),
      credentialProvider: const StaticLiveAgentCredentialProvider('test-key'),
    );
    addTearDown(coordinator.dispose);
    await coordinator.start(document: _document(1, 'Source book'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userIdProvider.overrideWithValue(null),
          sockWsUrlProvider.overrideWithValue(null),
          imageBaseUrlProvider.overrideWithValue(null),
          noteLiveConversationCoordinatorProvider.overrideWithValue(
            coordinator,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: NoteCompanion(document: _document(1, 'Book'))),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('ios-live-conversation-bottom-bar')),
      findsOneWidget,
    );
    expect(find.byTooltip('Mute microphone'), findsOneWidget);
    expect(find.byTooltip('Stop live conversation'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
    expect(find.byIcon(Icons.headphones_rounded), findsNothing);

    await tester.tap(find.byTooltip('Mute microphone'));
    await tester.pump();

    expect(transport.inputEnabledValues, [false]);
    expect(find.byTooltip('Unmute microphone'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('expanded Mac panel uses the same four live controls', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final transport = _FakeTransport();
    final coordinator = NoteLiveConversationCoordinator(
      createController: () => NoteLiveConversationController(
        session: LiveAgentSession(transport: transport),
      ),
      credentialProvider: const StaticLiveAgentCredentialProvider('test-key'),
    );
    addTearDown(coordinator.dispose);
    await coordinator.start(document: _document(2, 'Chapter'));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 620,
            child: NoteLiveConversationPanel(
              coordinator: coordinator,
              onEnd: () {},
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('mac-live-conversation-controls')),
      findsOneWidget,
    );
    expect(find.byTooltip('Pause live playback'), findsOneWidget);
    expect(find.byTooltip('Mute microphone'), findsOneWidget);
    expect(find.byTooltip('Stop live conversation'), findsOneWidget);
    expect(find.byTooltip('Turn off automatic VAD'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('note-live-end-button')),
      findsNothing,
    );
    debugDefaultTargetPlatformOverride = null;
  });
}

NxDocument _document(int id, String title) => NxDocument(
  id: id,
  title: title,
  modelTypeName: id == 1 ? 'Book' : 'BookChapter',
  document: 'Document $id body',
  jsonDocument: const {},
  wordCount: 3,
  status: 'Draft',
  topics: const [],
  areaTags: const [],
  tagsBySystem: const {},
  pinned: false,
  updatedAt: DateTime(2026),
  updatedLabel: 'now',
  versionNumber: 0,
  excerpt: 'Document body',
  links: const [],
);
