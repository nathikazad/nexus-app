import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/language/language_category_order.dart';

/// Page navigation groups, separate from scheduling/progression categories.
class LanguageGroup {
  const LanguageGroup(this.name, {this.tagSystem});

  final String name;
  final String? tagSystem;

  bool contains(StudyCard card) => tagSystem == null
      ? card.belongsToStudyCategory(name)
      : (card.tags[tagSystem] ?? const <String>[]).any(
          (value) => value.trim() == name,
        );
}

List<LanguageGroup> languageGroups(Iterable<StudyCard> cards) {
  final categories = orderedLanguageCategories(
    cards.expand((card) => card.studyCategories),
  );
  final tags = <(String, String)>{};
  for (final card in cards) {
    for (final entry in card.tags.entries) {
      if (entry.key == 'Language') continue;
      for (final value in entry.value) {
        final name = value.trim();
        if (name.isEmpty) continue;
        // These tags already back the existing word-category groups.
        if ((entry.key == 'Word Category' || entry.key == 'Part of Speech') &&
            categories.contains(name)) {
          continue;
        }
        tags.add((entry.key, name));
      }
    }
  }
  final sortedTags = tags.toList()
    ..sort((a, b) {
      final byName = a.$2.toLowerCase().compareTo(b.$2.toLowerCase());
      return byName != 0 ? byName : a.$1.compareTo(b.$1);
    });
  return [
    for (final name in categories) LanguageGroup(name),
    for (final (system, name) in sortedTags)
      LanguageGroup(name, tagSystem: system),
  ];
}
