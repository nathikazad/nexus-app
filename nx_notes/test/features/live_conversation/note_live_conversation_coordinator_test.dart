import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_live_agent/nx_live_agent.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/features/companion/note_companion.dart';
import 'package:nx_notes/features/live_conversation/note_live_conversation_controller.dart';
import 'package:nx_notes/features/live_conversation/note_live_conversation_coordinator.dart';

class _FakeTransport implements LiveAgentTransport {
  final eventsController = StreamController<LiveAgentEvent>.broadcast();
  int closeRequests = 0;

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
  Future<void> cancelResponse() async {}

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
  Future<void> requestResponse() async {}

  @override
  Future<void> sendInstruction(
    String text, {
    bool requestResponse = true,
  }) async {}

  @override
  Future<void> sendToolResult(String callId, Object? output) async {}

  @override
  Future<void> setMuted(bool muted) async {}
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
    'shows the same mobile Stop action after navigating to another document',
    (tester) async {
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
    },
  );
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
