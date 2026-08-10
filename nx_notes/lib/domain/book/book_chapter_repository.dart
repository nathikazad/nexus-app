import 'package:nx_notes/domain/book/book_chapter.dart';

abstract interface class BookChapterRepository {
  Future<List<BookChapterSummary>> listChapters(int bookId);

  Future<List<BookChapter>> loadSelectedChapters({
    required int bookId,
    required Set<int> chapterIds,
  });
}
