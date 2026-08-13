import 'package:flutter_test/flutter_test.dart';
import 'package:nx_live_agent/nx_live_agent.dart';

void main() {
  test('parses arbitrary Realtime function calls', () {
    final events = parseOpenAiRealtimeEvent({
      'type': 'response.done',
      'response': {
        'output': [
          {
            'type': 'function_call',
            'id': 'item-1',
            'name': 'get_current_examples',
            'call_id': 'call-1',
            'arguments': '{}',
          },
        ],
      },
    });

    expect(events.single.type, LiveAgentEventType.toolCall);
    expect(events.single.toolCall?.name, 'get_current_examples');
    expect(events.single.toolCall?.callId, 'call-1');
    expect(events.single.toolCall?.itemId, 'item-1');
  });

  test('builds a session from an app-owned spec and tools', () {
    const tool = LiveAgentToolDefinition(
      name: 'advance',
      description: 'Advance the item',
      parameters: {'type': 'object'},
    );
    final session = openAiRealtimeSession(
      spec: const LiveAgentSpec(
        instructions: 'Stay anchored.',
        model: 'test-model',
        voice: 'test-voice',
      ),
      tools: const [tool],
    );

    expect(session['model'], 'test-model');
    expect(session['instructions'], 'Stay anchored.');
    expect((session['tools'] as List).single, tool.toJson());
  });

  test('defines one reusable semantic VAD configuration', () {
    expect(openAiSemanticVad(), {
      'type': 'semantic_vad',
      'eagerness': 'medium',
      'create_response': true,
      'interrupt_response': true,
    });
  });

  test('GA turn-detection updates retain the realtime session type', () {
    final manual = openAiTurnDetectionUpdate(false);
    final automatic = openAiTurnDetectionUpdate(true);

    expect((manual['session']! as Map)['type'], 'realtime');
    expect(
      (((manual['session']! as Map)['audio']! as Map)['input']!
          as Map)['turn_detection'],
      isNull,
    );
    expect(
      (((automatic['session']! as Map)['audio']! as Map)['input']!
          as Map)['turn_detection'],
      openAiSemanticVad(),
    );
  });

  test('can disable input transcription for audio-only clients', () {
    final session = openAiRealtimeSession(
      spec: const LiveAgentSpec(
        instructions: 'Stay anchored.',
        enableInputTranscription: false,
        emitTranscripts: false,
        maxConversationPairs: 4,
      ),
      tools: const [],
    );

    final audio = session['audio'] as Map;
    final input = audio['input'] as Map;
    expect(input, isNot(contains('transcription')));
  });

  test('can start with automatic turn detection disabled', () {
    final session = openAiRealtimeSession(
      spec: const LiveAgentSpec(
        instructions: 'Wait for manual input.',
        turnDetectionMode: LiveAgentTurnDetectionMode.manual,
      ),
      tools: const [],
    );

    final audio = session['audio'] as Map;
    final input = audio['input'] as Map;
    expect(input['turn_detection'], isNull);
  });

  test('keeps only the requested number of complete conversation pairs', () {
    final obsolete = conversationItemIdsOutsideRecentPairs(const [
      (id: 'user-1', role: 'user'),
      (id: 'assistant-1', role: 'assistant'),
      (id: 'user-2', role: 'user'),
      (id: 'assistant-2', role: 'assistant'),
      (id: 'user-3', role: 'user'),
      (id: 'assistant-3', role: 'assistant'),
      (id: 'user-4', role: 'user'),
      (id: 'assistant-4', role: 'assistant'),
      (id: 'user-5', role: 'user'),
      (id: 'assistant-5', role: 'assistant'),
    ], 4);

    expect(obsolete, ['user-1', 'assistant-1']);
  });

  test('surfaces Realtime errors', () {
    final events = parseOpenAiRealtimeEvent({
      'type': 'error',
      'error': {'message': 'bad session'},
    });

    expect(events.single.type, LiveAgentEventType.error);
    expect(events.single.text, 'bad session');
  });

  test('distinguishes user speech from ordinary listening state', () {
    final speech = parseOpenAiRealtimeEvent({
      'type': 'input_audio_buffer.speech_started',
    });
    final completed = parseOpenAiRealtimeEvent({
      'type': 'response.done',
      'response': {'output': <Object?>[]},
    });

    expect(speech.single.type, LiveAgentEventType.userSpeechStarted);
    expect(completed.single.type, LiveAgentEventType.listening);
  });

  test('distinguishes completed client audio playback', () {
    final events = parseOpenAiRealtimeEvent({
      'type': 'output_audio_buffer.stopped',
    });

    expect(events.single.type, LiveAgentEventType.playbackStopped);
  });

  test('parses detailed token usage from completed responses', () {
    final events = parseOpenAiRealtimeEvent({
      'type': 'response.done',
      'response': {
        'output': <Object?>[],
        'usage': {
          'input_tokens': 1100,
          'output_tokens': 550,
          'input_token_details': {
            'text_tokens': 1000,
            'audio_tokens': 100,
            'cached_tokens': 220,
            'cached_tokens_details': {'text_tokens': 200, 'audio_tokens': 20},
          },
          'output_token_details': {'text_tokens': 500, 'audio_tokens': 50},
        },
      },
    });

    expect(events, hasLength(2));
    expect(events.first.type, LiveAgentEventType.usage);
    expect(events.first.usage?.inputTokens, 1100);
    expect(events.first.usage?.cachedInputAudioTokens, 20);
    expect(events.first.usage?.outputAudioTokens, 50);
    expect(events.last.type, LiveAgentEventType.listening);
  });

  test('parses separately billed input transcription usage', () {
    final events = parseOpenAiRealtimeEvent({
      'type': 'conversation.item.input_audio_transcription.completed',
      'transcript': 'next',
      'usage': {'total_tokens': 50, 'input_tokens': 40, 'output_tokens': 10},
    });

    expect(events, hasLength(2));
    expect(events.first.type, LiveAgentEventType.usage);
    expect(events.first.usage?.transcriptionInputTokens, 40);
    expect(events.first.usage?.transcriptionOutputTokens, 10);
    expect(events.last.type, LiveAgentEventType.transcript);
    expect(events.last.text, 'next');
  });
}
