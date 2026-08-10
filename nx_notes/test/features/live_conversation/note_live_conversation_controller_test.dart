import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_live_agent/nx_live_agent.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/features/live_conversation/note_live_conversation_controller.dart';

class _FakeTransport implements LiveAgentTransport {
  final eventsController = StreamController<LiveAgentEvent>.broadcast();
  LiveAgentSpec? connectedSpec;
  int closeRequests = 0;

  @override
  Stream<LiveAgentEvent> get events => eventsController.stream;

  @override
  Future<void> connect({
    required String credential,
    required LiveAgentSpec spec,
    required List<LiveAgentToolDefinition> tools,
  }) async {
    connectedSpec = spec;
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
  Future<void> dispose() async => eventsController.close();

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
  test(
    'starts a transcript-free four-pair session with a frozen document',
    () async {
      final transport = _FakeTransport();
      final controller = NoteLiveConversationController(
        session: LiveAgentSession(transport: transport),
      );

      await controller.start(
        document: _document(),
        credentialProvider: const StaticLiveAgentCredentialProvider('test-key'),
      );
      await pumpEventQueue();

      final spec = transport.connectedSpec!;
      expect(spec.model, 'gpt-realtime-2.1-mini');
      expect(spec.enableInputTranscription, isFalse);
      expect(spec.emitTranscripts, isFalse);
      expect(spec.maxConversationPairs, 4);
      expect(spec.initialContext, isNull);
      expect(spec.instructions, contains('<document_snapshot>'));
      expect(spec.instructions, contains('The document body'));
      expect(controller.phase, LiveAgentPhase.listening);

      transport.eventsController.add(
        const LiveAgentEvent(
          LiveAgentEventType.usage,
          usage: LiveAgentUsage(
            inputTokens: 2000,
            outputTokens: 1000,
            inputTextTokens: 1000,
            inputAudioTokens: 1000,
            cachedInputTokens: 600,
            cachedInputTextTokens: 400,
            cachedInputAudioTokens: 200,
            outputTextTokens: 500,
            outputAudioTokens: 500,
          ),
        ),
      );
      await pumpEventQueue();

      expect(controller.usage.totalTokens, 3000);
      expect(controller.inputCost, closeTo(0.008444, 0.0000001));
      expect(controller.outputCost, closeTo(0.0112, 0.0000001));
      expect(controller.totalCost, closeTo(0.019644, 0.0000001));

      await controller.end();
      expect(transport.closeRequests, 1);
      controller.dispose();
    },
  );
}

NxDocument _document() => NxDocument(
  id: 42,
  title: 'Test note',
  modelTypeName: 'Document',
  document: 'The document body',
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
  excerpt: 'The document body',
  links: const [],
);
