import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/domain/voice/voice_transcript.dart';

void main() {
  test('copyWithMessage replaces by timestamp key', () {
    const msg1 = VoiceTranscriptMessage(
      message: 'a',
      isFromUser: true,
      timestamp: '1',
    );
    const msg2 = VoiceTranscriptMessage(
      message: 'b',
      isFromUser: false,
      timestamp: '1',
    );
    final t = VoiceTranscript(
      id: 1,
      messages: {'1': msg1},
    );
    final next = t.copyWithMessage(msg2);
    expect(next.messages['1']!.message, 'b');
    expect(next.messages['1']!.isFromUser, false);
  });

  test('sortedMessages orders by timestamp key', () {
    final t = VoiceTranscript(
      id: 1,
      messages: {
        '2': const VoiceTranscriptMessage(
          message: 'second',
          isFromUser: true,
          timestamp: '2',
        ),
        '1': const VoiceTranscriptMessage(
          message: 'first',
          isFromUser: true,
          timestamp: '1',
        ),
      },
    );
    expect(t.sortedMessages.map((m) => m.message).toList(), ['first', 'second']);
  });
}
