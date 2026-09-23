import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/language/language_category_order.dart';

/// Only explicitly supported tag systems are navigation groups.
class LanguageGroup {
  const LanguageGroup(this.name, {this.tagSystem = 'Category'});
  final String name;
  final String? tagSystem;
  bool contains(StudyCard card) =>
      (card.tags[tagSystem ?? 'Category'] ?? const <String>[]).any(
        (value) => value.trim() == name,
      );
}

List<LanguageGroup> languageGroups(
  Iterable<StudyCard> cards, {
  String tagSystem = 'Category',
}) {
  if (tagSystem != 'Category' && tagSystem != 'Collection') return [];
  final names = orderedLanguageCategories(
    cards.expand((card) => card.tags[tagSystem] ?? const <String>[]),
  );
  return [for (final name in names) LanguageGroup(name, tagSystem: tagSystem)];
}
