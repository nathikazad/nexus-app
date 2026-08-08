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
}
