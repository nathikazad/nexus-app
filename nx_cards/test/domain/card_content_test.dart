import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/domain/cards_models.dart';

void main() {
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
      );

      expect(content.front, 'talent');
      expect(content.back, 'കഴിവ്');
      expect(content.english, 'talent');
      expect(content.originalScript, 'കഴിവ്');
      expect(content.transliteration, 'kazhivu');
      expect(content.audioUrl, endsWith('12-abcd.mp3'));
    },
  );
}
