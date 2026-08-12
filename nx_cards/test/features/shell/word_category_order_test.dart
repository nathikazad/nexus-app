import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/features/shell/word_category_order.dart';

void main() {
  test('orders present categories with Script and Noun first', () {
    expect(
      orderedWordCategories([
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
    expect(orderedWordCategories(['Verb', 'Adverb']), ['Verb', 'Adverb']);
  });
}
