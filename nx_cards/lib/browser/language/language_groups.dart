import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/language/language_category_order.dart';

class LanguageGroup {
  const LanguageGroup(this.name, {this.tagSystem = 'Category', this.path});
  final String name;
  final String? tagSystem;
  final List<String>? path;
  bool contains(StudyCard card) => tagSystem == null || tagSystem == 'Category'
      ? path == null
            ? card.hasCategory(name)
            : card.hasCategoryPath(path!)
      : (card.tags[tagSystem] ?? const []).contains(name);
}

/// Only populated branches in this language become navigation groups.
List<LanguageGroup> languageGroups(
  Iterable<StudyCard> cards, {
  String tagSystem = 'Category',
  List<String> parent = const [],
}) {
  if (tagSystem != 'Category' && tagSystem != 'Collection') return [];
  final names = orderedLanguageCategories(
    tagSystem == 'Category'
        ? cards.expand(
            (card) => card.categoryPaths
                .where(
                  (path) =>
                      path.length > parent.length &&
                      Iterable<int>.generate(
                        parent.length,
                      ).every((i) => path[i] == parent[i]),
                )
                .map((path) => path[parent.length]),
          )
        : cards.expand((card) => card.tags[tagSystem] ?? const <String>[]),
  );
  return [
    for (final name in names)
      LanguageGroup(
        name,
        tagSystem: tagSystem,
        path: tagSystem == 'Category' ? [...parent, name] : null,
      ),
  ];
}
