import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/features/study/language_audio_controls.dart';

void main() {
  group('language audio labels', () {
    test('formats playback duration as minutes and seconds', () {
      expect(formatAudioDuration(Duration.zero), '0:00');
      expect(formatAudioDuration(const Duration(seconds: 7)), '0:07');
      expect(
        formatAudioDuration(const Duration(minutes: 2, seconds: 4)),
        '2:04',
      );
    });

    test('formats the supported playback rates', () {
      expect(formatPlaybackRate(0.25), '0.25×');
      expect(formatPlaybackRate(0.5), '0.5×');
      expect(formatPlaybackRate(1), '1×');
    });
  });
}
