import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';

void main() {
  test(
    'identical vocabulary is not shown as its own example, including cached JSON',
    () {
      for (final text in ['生日', '苹果']) {
        final content = LanguageCardContent(
          english: 'word',
          originalScript: text,
          transliteration: 'pinyin',
          examples: [
            LanguageExample.fromJson({
              'text': text,
              'translation': 'word',
              'transliteration': 'pinyin',
            }),
            LanguageExample(
              text: '我喜欢$text',
              translation: 'I like it',
              transliteration: 'pinyin',
            ),
          ],
        );
        expect(content.examples.map((e) => e.text), ['我喜欢$text']);
      }
    },
  );

  test('basic content exposes an ordinary front and back', () {
    const content = BasicCardContent(front: 'Question', back: 'Answer');

    expect(content.front, 'Question');
    expect(content.back, 'Answer');
  });

  test(
    'language content keeps generic and language-specific views aligned',
    () {
      const content = LanguageCardContent(
        english: 'talent',
        originalScript: 'കഴിവ്',
        transliteration: 'kazhivu',
        audioUrl: '/cards/assets/audio/file?user_id=1&name=12-abcd.mp3',
        examples: <LanguageExample>[
          LanguageExample(
            text: 'അവന് നല്ല കഴിവുണ്ട്.',
            transliteration: 'avan nalla kazhivundu',
            translation: 'He has good talent.',
          ),
        ],
      );

      expect(content.front, 'talent');
      expect(content.back, 'കഴിവ്');
      expect(content.english, 'talent');
      expect(content.originalScript, 'കഴിവ്');
      expect(content.transliteration, 'kazhivu');
      expect(content.audioUrl, endsWith('12-abcd.mp3'));
      expect(content.examples.single.translation, 'He has good talent.');
      expect(content.examples.single.toJson(), isNot(contains('audio_url')));
    },
  );
}
