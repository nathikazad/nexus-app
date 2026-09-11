import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/chinese_word_characters.dart';

StudyCard card(
  int id,
  String text, {
  String type = 'Word',
  String language = 'Chinese',
}) => StudyCard(
  id: id,
  modelTypeName: type,
  content: LanguageCardContent(
    english: text,
    originalScript: text,
    transliteration: text,
  ),
  tags: {
    'Language': [language],
  },
  schedules: {},
  reviewHistory: {},
  suspended: false,
);

void main() {
  test('student opens its characters without flattening the sentence', () {
    final learn = card(1, '学', type: 'Verb');
    final life = card(2, '生');
    final student = card(3, '学生');
    final sentence = card(4, '我是学生', type: 'Phrase');
    final library = [
      life,
      student,
      sentence,
      learn,
      card(5, '学', language: 'Japanese'),
    ];
    expect(chineseWordCharacters(student, library).map((c) => c.id), [1, 2]);
    expect(chineseWordCharacters(sentence, library), isEmpty);
    expect(chineseWordCharacters(learn, library), isEmpty);
  });
  test('repeated characters retain their positions', () {
    final dad = card(1, '爸');
    expect(chineseWordCharacters(card(2, '爸爸'), [dad]).map((c) => c.id), [
      1,
      1,
    ]);
  });
}
