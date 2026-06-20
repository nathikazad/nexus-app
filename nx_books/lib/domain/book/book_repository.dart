import 'book.dart';

abstract class BookRepository {
  Future<List<NxBook>> listBooks();
  Future<List<String>> listTopicTags();
  Future<NxBook> createBook({String? title});
  Future<void> updateBookState({
    required int id,
    required BookReadingState state,
    required int rank,
  });
  Future<void> updateBookRank({required int id, required int rank});
  Future<void> updateBookTopicTags({
    required int id,
    required List<String> tags,
  });
  Future<void> updateBookChapterProgress({
    required int id,
    required int? totalChapters,
    required int? currentChapter,
  });
  Future<void> deleteBook(int id);
}
