import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/features/shell/language_category_order.dart';

void main() {
  test('orders present categories with Script and Noun first', () {
    expect(
      orderedLanguageCategories([
        'Verb',
        'Noun',
        'Future category',
        'Script',
        'Adjective',
        'Verb',
        null,
        '',
      ]),
      ['Script', 'Noun', 'Verb', 'Adjective', 'Future category'],
    );
  });

  test('does not create priority categories when they are absent', () {
    expect(orderedLanguageCategories(['Verb', 'Adverb']), ['Verb', 'Adverb']);
  });
}
