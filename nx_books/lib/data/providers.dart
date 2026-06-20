import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_books/data/book/kgql_book_repository.dart';
import 'package:nx_books/domain/book/book.dart';
import 'package:nx_books/domain/book/book_repository.dart';
import 'package:nx_db/riverpod.dart';

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return KgqlBookRepository(client: ref.watch(graphqlClientProvider));
});

final booksProvider = FutureProvider<List<NxBook>>((ref) {
  return ref.watch(bookRepositoryProvider).listBooks();
});

final topicTagsProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(bookRepositoryProvider).listTopicTags();
});

final selectedBookIdProvider = NotifierProvider<SelectedBookId, int?>(
  SelectedBookId.new,
);

final searchQueryProvider = NotifierProvider<SearchQuery, String>(
  SearchQuery.new,
);

final mobileStateProvider = NotifierProvider<MobileBookState, BookReadingState>(
  MobileBookState.new,
);

final bookMutationControllerProvider = Provider<BookMutationController>(
  BookMutationController.new,
);

class BookMutationController {
  BookMutationController(this._ref);

  final Ref _ref;

  Future<NxBook> createBook({String? title}) async {
    final book = await _ref
        .read(bookRepositoryProvider)
        .createBook(title: title);
    _ref.invalidate(booksProvider);
    _ref.read(selectedBookIdProvider.notifier).select(book.id);
    return book;
  }

  Future<void> changeState(NxBook book, BookReadingState state) async {
    if (book.readingState == state) return;
    final books = await _ref.read(booksProvider.future);
    final rank = _nextRank(books, state);
    await _ref
        .read(bookRepositoryProvider)
        .updateBookState(id: book.id, state: state, rank: rank);
    _ref.invalidate(booksProvider);
  }

  Future<void> moveWithinLane(NxBook book, int delta) async {
    final books = await _ref.read(booksProvider.future);
    final lane = sortedBooksForState(books, book.readingState);
    final currentIndex = lane.indexWhere((item) => item.id == book.id);
    if (currentIndex == -1) return;
    final nextIndex = (currentIndex + delta).clamp(0, lane.length - 1).toInt();
    if (currentIndex == nextIndex) return;

    final reordered = [...lane];
    final item = reordered.removeAt(currentIndex);
    reordered.insert(nextIndex, item);

    for (var i = 0; i < reordered.length; i++) {
      final row = reordered[i];
      if (row.rank == i) continue;
      await _ref
          .read(bookRepositoryProvider)
          .updateBookRank(id: row.id, rank: i);
    }
    _ref.invalidate(booksProvider);
  }

  Future<void> updateTopicTags(NxBook book, List<String> tags) async {
    await _ref
        .read(bookRepositoryProvider)
        .updateBookTopicTags(id: book.id, tags: tags);
    _ref.invalidate(booksProvider);
    _ref.invalidate(topicTagsProvider);
  }

  int _nextRank(List<NxBook> books, BookReadingState state) {
    final ranks = [
      for (final book in books)
        if (book.readingState == state && book.rank != null) book.rank!,
    ];
    if (ranks.isEmpty) return 0;
    return ranks.reduce((a, b) => a > b ? a : b) + 1;
  }
}

class SelectedBookId extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? id) {
    state = id;
  }
}

class SearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) {
    state = value;
  }
}

class MobileBookState extends Notifier<BookReadingState> {
  @override
  BookReadingState build() => BookReadingState.reading;

  void set(BookReadingState value) {
    state = value;
  }
}
