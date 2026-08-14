import 'package:nx_docs/books/book_chapter.dart';

abstract interface class BookChapterRepository {
  Future<List<BookChapterSummary>> listChapters(int bookId);

  Future<List<BookChapter>> loadSelectedChapters({
    required int bookId,
    required Set<int> chapterIds,
  });
}
