import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/data/voice/voice_transcript_mapping.dart';
import 'package:nx_db/nx_db.dart' as nx;

void main() {
  test('mapTranscriptMessage copies fields', () {
    final m = nx.TranscriptMessage(
      timestamp: 't1',
      sender: 'Human',
      message: 'hi',
    );
    final v = mapTranscriptMessage(m);
    expect(v.timestamp, 't1');
    expect(v.message, 'hi');
    expect(v.isFromUser, true);
  });

  test('mapTranscript returns null for null input', () {
    expect(mapTranscript(null), isNull);
  });

  test('mapTranscript maps message entries', () {
    final t = nx.Transcript(
      id: 7,
      messages: {
        'a': nx.TranscriptMessage(timestamp: 'a', sender: 'AI', message: 'x'),
      },
    );
    final v = mapTranscript(t)!;
    expect(v.id, 7);
    expect(v.messages.length, 1);
    expect(v.messages['a']!.isFromUser, false);
  });
}
