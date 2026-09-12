import 'package:nx_documents/nx_documents.dart';
import 'book_source.dart';

/// Only actual chapter models linked to this Book may expose a source action.
BookSource? chapterBookSource(
  DocumentContent content,
  Map<String, dynamic> headingData,
) {
  if (content.modelTypeName != 'Book Chapter') return null;
  final source = BookSource.fromJson(headingData['book_source']);
  if (source == null ||
      !content.modelRelations.any(
        (r) =>
            r.id == source.bookId &&
            r.modelType == 'Book' &&
            r.relationName == 'book_book_chapter',
      )) {
    return null;
  }
  return source;
}
