import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_live_agent/nx_live_agent.dart';

class _FakeTransport implements LiveAgentTransport {
  final controller = StreamController<LiveAgentEvent>.broadcast();
  final results = <String, Object?>{};
  int responseRequests = 0;
  int cancelRequests = 0;
  int closeRequests = 0;
  final mutedValues = <bool>[];
  final discardedKeepItemIds = <Set<String>>[];

  @override
  Stream<LiveAgentEvent> get events => controller.stream;

  @override
  Future<void> connect({
    required String credential,
    required LiveAgentSpec spec,
    required List<LiveAgentToolDefinition> tools,
  }) async {}

  @override
  Future<void> sendToolResult(String callId, Object? output) async {
    results[callId] = output;
  }

  @override
  Future<void> discardConversation({
    Set<String> keepItemIds = const {},
  }) async => discardedKeepItemIds.add(Set<String>.of(keepItemIds));

  @override
  Future<void> requestResponse() async => responseRequests += 1;

  @override
  Future<void> sendInstruction(
    String text, {
    bool requestResponse = true,
  }) async {}

  @override
  Future<void> cancelResponse() async => cancelRequests += 1;

  @override
  Future<void> setMuted(bool muted) async => mutedValues.add(muted);

  @override
  Future<void> close() async => closeRequests += 1;

  @override
  Future<void> dispose() async => controller.close();
}

void main() {
  test(
    'starts in listening state when no initial response is requested',
    () async {
      final transport = _FakeTransport();
      final session = LiveAgentSession(transport: transport);
      await session.start(
        credentialProvider: const StaticLiveAgentCredentialProvider('test-key'),
        spec: const LiveAgentSpec(instructions: 'Test'),
        tools: const [],
      );

      transport.controller.add(
        const LiveAgentEvent(LiveAgentEventType.connected),
      );
      await pumpEventQueue();

      expect(session.phase, LiveAgentPhase.listening);
      session.dispose();
    },
  );

  test('dispatches generic tools once and returns their output', () async {
    final transport = _FakeTransport();
    final session = LiveAgentSession(transport: transport);
    var calls = 0;
    await session.start(
      credentialProvider: const StaticLiveAgentCredentialProvider('test-key'),
      spec: const LiveAgentSpec(instructions: 'Test'),
      tools: [
        CallbackLiveAgentTool(
          definition: const LiveAgentToolDefinition(
            name: 'lookup',
            description: 'Lookup a value',
            parameters: {'type': 'object'},
          ),
          onInvoke: (arguments) {
            calls += 1;
            return LiveAgentToolResult({'value': arguments['query']});
          },
        ),
      ],
    );
    const call = LiveAgentEvent(
      LiveAgentEventType.toolCall,
      toolCall: LiveAgentToolCall(
        callId: 'call-1',
        name: 'lookup',
        arguments: {'query': 'talent'},
      ),
    );

    transport.controller.add(call);
    transport.controller.add(call);
    await pumpEventQueue();

    expect(calls, 1);
    expect((transport.results['call-1'] as Map)['value'], 'talent');
    expect(transport.responseRequests, 1);
    session.dispose();
  });

  test('a tool can discard old conversation before its response', () async {
    final transport = _FakeTransport();
    final session = LiveAgentSession(transport: transport);
    await session.start(
      credentialProvider: const StaticLiveAgentCredentialProvider('test-key'),
      spec: const LiveAgentSpec(instructions: 'Test'),
      tools: [
        CallbackLiveAgentTool(
          definition: const LiveAgentToolDefinition(
            name: 'advance',
            description: 'Advance',
            parameters: {'type': 'object'},
          ),
          onInvoke: (_) => const LiveAgentToolResult({
            'ok': true,
          }, discardConversationBeforeResponse: true),
        ),
      ],
    );

    transport.controller.add(
      const LiveAgentEvent(
        LiveAgentEventType.toolCall,
        toolCall: LiveAgentToolCall(
          callId: 'call-advance',
          itemId: 'item-advance',
          name: 'advance',
          arguments: {},
        ),
      ),
    );
    await pumpEventQueue();

    expect(transport.discardedKeepItemIds, [
      <String>{'item-advance'},
    ]);
    expect(transport.results['call-advance'], {'ok': true});
    expect(transport.responseRequests, 1);
    session.dispose();
  });

  test('counts user speech over assistant audio as an interruption', () async {
    final transport = _FakeTransport();
    final session = LiveAgentSession(transport: transport);
    await session.start(
      credentialProvider: const StaticLiveAgentCredentialProvider('test-key'),
      spec: const LiveAgentSpec(instructions: 'Test'),
      tools: const [],
    );

    transport.controller.add(const LiveAgentEvent(LiveAgentEventType.speaking));
    transport.controller.add(
      const LiveAgentEvent(LiveAgentEventType.userSpeechStarted),
    );
    await pumpEventQueue();

    expect(session.interruptionCount, 1);
    expect(session.phase, LiveAgentPhase.listening);
    session.dispose();
  });

  test('closes only after the requested audio playback finishes', () async {
    final transport = _FakeTransport();
    final session = LiveAgentSession(transport: transport);
    await session.start(
      credentialProvider: const StaticLiveAgentCredentialProvider('test-key'),
      spec: const LiveAgentSpec(instructions: 'Test'),
      tools: const [],
    );
    session.closeAfterNextPlayback();

    transport.controller.add(
      const LiveAgentEvent(LiveAgentEventType.listening),
    );
    await pumpEventQueue();
    expect(transport.closeRequests, 0);

    transport.controller.add(
      const LiveAgentEvent(LiveAgentEventType.playbackStopped),
    );
    await pumpEventQueue();

    expect(session.playbackCompletionCount, 1);
    expect(transport.closeRequests, 1);
    expect(session.phase, LiveAgentPhase.closed);
    session.dispose();
  });

  test('keeps only the latest user and assistant transcript turns', () async {
    final transport = _FakeTransport();
    final session = LiveAgentSession(transport: transport);
    await session.start(
      credentialProvider: const StaticLiveAgentCredentialProvider('test-key'),
      spec: const LiveAgentSpec(instructions: 'Test'),
      tools: const [],
    );

    transport.controller.add(
      const LiveAgentEvent(
        LiveAgentEventType.transcript,
        role: 'assistant',
        text: 'First question?',
      ),
    );
    transport.controller.add(
      const LiveAgentEvent(
        LiveAgentEventType.transcript,
        role: 'user',
        text: 'First answer',
      ),
    );
    transport.controller.add(
      const LiveAgentEvent(
        LiveAgentEventType.transcript,
        role: 'assistant',
        text: 'That is ',
      ),
    );
    transport.controller.add(
      const LiveAgentEvent(
        LiveAgentEventType.transcript,
        role: 'assistant',
        text: 'correct.',
      ),
    );
    await pumpEventQueue();

    expect(session.latestUserTranscript, 'First answer');
    expect(session.latestAssistantTranscript, 'That is correct.');

    transport.controller.add(
      const LiveAgentEvent(LiveAgentEventType.userSpeechStarted),
    );
    transport.controller.add(
      const LiveAgentEvent(
        LiveAgentEventType.transcript,
        role: 'user',
        text: 'Next question',
      ),
    );
    await pumpEventQueue();

    expect(session.latestUserTranscript, 'Next question');
    expect(session.latestAssistantTranscript, isEmpty);
    session.dispose();
  });

  test(
    'pausing while listening does not cancel a nonexistent response',
    () async {
      final transport = _FakeTransport();
      final session = LiveAgentSession(transport: transport);
      await session.start(
        credentialProvider: const StaticLiveAgentCredentialProvider('test-key'),
        spec: const LiveAgentSpec(instructions: 'Test'),
        tools: const [],
      );
      transport.controller.add(
        const LiveAgentEvent(LiveAgentEventType.listening),
      );
      await pumpEventQueue();

      await session.setPaused(true);

      expect(transport.cancelRequests, 0);
      expect(transport.mutedValues, [true]);
      expect(session.phase, LiveAgentPhase.paused);
      session.dispose();
    },
  );
}
