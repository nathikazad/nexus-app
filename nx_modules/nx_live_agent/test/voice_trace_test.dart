import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_live_agent/nx_live_agent.dart';

void main() {
  test(
    'correlates late playback with its origin and counts terminal events once',
    () {
      final lines = <String>[];
      final trace = VoiceTrace(write: lines.add, sessionId: 'test');
      trace.card(1, 0);
      trace.wire('receive', {
        'type': 'response.created',
        'response': {'id': 'r1'},
      });
      trace.wire('receive', {
        'type': 'input_audio_buffer.speech_stopped',
        'item_id': 'u1',
      });
      trace.wire('receive', {
        'type': 'response.done',
        'response': {'id': 'r1'},
      });
      trace.card(2, 1);
      for (var i = 0; i < 2; i++) {
        trace.wire('receive', {
          'type': 'output_audio_buffer.stopped',
          'response_id': 'r1',
        });
      }
      final records = decode(lines);
      final last = records.last;
      expect(last['card_id'], 2);
      expect(last['data']['origin_card_visit'], 1);
      expect(last['speech_stops'], 1);
      expect(last['responses_done'], 1);
      expect(last['playback_stops'], 1);
      expect(records.map((r) => r['seq']).toSet().length, records.length);
    },
  );
  test(
    'preserves long text and excludes raw audio and session credentials',
    () {
      final lines = <String>[];
      final trace = VoiceTrace(write: lines.add);
      final text = 'Feng 风 ' * 500;
      trace.wire('receive', {
        'type': 'response.output_audio_transcript.delta',
        'delta': text,
      });
      trace.wire('receive', {
        'type': 'response.output_audio.delta',
        'delta': 'RAW_AUDIO',
      });
      trace.wire('receive', {
        'type': 'session.created',
        'session': {'client_secret': 'SECRET'},
      });
      expect(decode(lines).first['data']['delta'], text);
      expect(lines.join(), isNot(contains('RAW_AUDIO')));
      expect(lines.join(), isNot(contains('SECRET')));
    },
  );
  test('broken logging sink cannot interrupt tutoring', () {
    final trace = VoiceTrace(write: (_) => throw StateError('sink failed'));
    expect(() => trace.card(1, 0), returnsNormally);
    expect(
      () => trace.wire('receive', {'type': 'response.done'}),
      returnsNormally,
    );
  });
}

List<dynamic> decode(List<String> lines) {
  final parts = <int, StringBuffer>{};
  for (final line in lines) {
    final part = jsonDecode(line.substring('NxVoiceTrace '.length));
    parts.putIfAbsent(part['seq'], StringBuffer.new).write(part['fragment']);
  }
  return parts.values.map((s) => jsonDecode(s.toString())).toList();
}
