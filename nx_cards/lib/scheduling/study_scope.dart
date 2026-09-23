import 'package:nx_cards/browser/browser.dart';

/// Explicit session selection; never the first tag of an individual card.
class StudyScope {
  const StudyScope({this.language, this.tagSystem, this.tag, this.bookId});
  final String? language;
  final String? tagSystem;
  final String? tag;
  final int? bookId;

  bool contains(StudyCard card) =>
      (language == null || card.language == language) &&
      (bookId == null || card.sourceBookId == bookId) &&
      (tag == null ||
          (card.tags[tagSystem ?? 'Category'] ?? const []).contains(tag));
}
