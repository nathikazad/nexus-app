import 'dart:async';

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

final selectedTopicTagProvider = NotifierProvider<SelectedTopicTag, String?>(
  SelectedTopicTag.new,
);

final availableBookTagsProvider = Provider<List<String>>((ref) {
  final tags = <String, String>{};
  void addTag(String value) {
    final tag = value.trim();
    if (tag.isNotEmpty) tags.putIfAbsent(tag.toLowerCase(), () => tag);
  }

  for (final tag in ref.watch(topicTagsProvider).value ?? const <String>[]) {
    addTag(tag);
  }
  for (final book in ref.watch(booksProvider).value ?? const <NxBook>[]) {
    for (final tag in book.tags) {
      addTag(tag);
    }
  }
  final result = tags.values.toList();
  result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return result;
});

final bookCollectionStateProvider =
    NotifierProvider<BookCollectionState, BookReadingState>(
      BookCollectionState.new,
    );

final optimisticBookOrdersProvider =
    NotifierProvider<
      OptimisticBookOrders,
      Map<BookReadingState, OptimisticBookOrder>
    >(OptimisticBookOrders.new);

final bookMutationControllerProvider = Provider<BookMutationController>(
  BookMutationController.new,
);

class BookMutationController {
  BookMutationController(this._ref);

  final Ref _ref;
  final Map<BookReadingState, Future<void>> _laneSaveChains = {};

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
    final lane = _currentLane(books, book.readingState);
    final currentIndex = lane.indexWhere((item) => item.id == book.id);
    if (currentIndex == -1) return;
    final nextIndex = (currentIndex + delta).clamp(0, lane.length - 1).toInt();
    if (currentIndex == nextIndex) return;

    final reordered = [...lane];
    final item = reordered.removeAt(currentIndex);
    reordered.insert(nextIndex, item);

    await _saveLaneOrder(reordered);
  }

  Future<void> reorderWithinLane({
    required NxBook book,
    required NxBook target,
    required bool placeAfter,
  }) async {
    if (book.id == target.id || book.readingState != target.readingState) {
      return;
    }
    final books = await _ref.read(booksProvider.future);
    final reordered = _currentLane(books, book.readingState);
    final currentIndex = reordered.indexWhere((item) => item.id == book.id);
    if (currentIndex == -1) return;
    final item = reordered.removeAt(currentIndex);
    final targetIndex = reordered.indexWhere((row) => row.id == target.id);
    if (targetIndex == -1) return;
    reordered.insert(targetIndex + (placeAfter ? 1 : 0), item);

    await _saveLaneOrder(reordered);
  }

  Future<void> _saveLaneOrder(List<NxBook> reordered) async {
    if (reordered.isEmpty) return;
    final lane = reordered.first.readingState;
    final order = _ref.read(optimisticBookOrdersProvider.notifier).setOrder(
      lane,
      [for (final book in reordered) book.id],
    );
    final previous = _laneSaveChains[lane] ?? Future<void>.value();
    final save = previous
        .catchError((_) {})
        .then((_) => _persistLaneOrder(reordered, order));
    _laneSaveChains[lane] = save;
    await save;
  }

  List<NxBook> _currentLane(List<NxBook> books, BookReadingState lane) {
    final optimistic = _ref.read(optimisticBookOrdersProvider)[lane];
    return booksInLaneOrder(books, lane, optimistic?.bookIds);
  }

  Future<void> _persistLaneOrder(
    List<NxBook> reordered,
    OptimisticBookOrder order,
  ) async {
    final lane = reordered.first.readingState;
    final repository = _ref.read(bookRepositoryProvider);
    try {
      await Future.wait([
        for (var i = 0; i < reordered.length; i++)
          if (reordered[i].rank != i)
            repository.updateBookRank(id: reordered[i].id, rank: i),
      ]).timeout(const Duration(seconds: 20));
      _ref.invalidate(booksProvider);
      await _ref.read(booksProvider.future);
      _ref
          .read(optimisticBookOrdersProvider.notifier)
          .clear(lane, order.revision);
    } catch (_) {
      _ref
          .read(optimisticBookOrdersProvider.notifier)
          .clear(lane, order.revision);
      rethrow;
    }
  }

  Future<void> updateTopicTags(NxBook book, List<String> tags) async {
    await _ref
        .read(bookRepositoryProvider)
        .updateBookTopicTags(id: book.id, tags: tags);
    _ref.invalidate(booksProvider);
    _ref.invalidate(topicTagsProvider);
  }

  Future<void> updateChapterProgress(
    NxBook book, {
    required int? totalChapters,
    required int? currentChapter,
  }) async {
    int? nextTotal = totalChapters;
    int? nextCurrent = currentChapter;
    if (nextTotal != null && nextTotal <= 0) {
      nextTotal = null;
      nextCurrent = null;
    } else if (nextTotal != null) {
      nextCurrent = (nextCurrent ?? book.currentChapter ?? 0).clamp(
        0,
        nextTotal,
      );
    } else {
      nextCurrent = null;
    }

    await _ref
        .read(bookRepositoryProvider)
        .updateBookChapterProgress(
          id: book.id,
          totalChapters: nextTotal,
          currentChapter: nextCurrent,
        );
    _ref.invalidate(booksProvider);
  }

  Future<void> deleteBook(NxBook book) async {
    await _ref.read(bookRepositoryProvider).deleteBook(book.id);
    final selected = _ref.read(selectedBookIdProvider);
    if (selected == book.id) {
      _ref.read(selectedBookIdProvider.notifier).select(null);
    }
    _ref.invalidate(booksProvider);
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

class OptimisticBookOrder {
  const OptimisticBookOrder({required this.revision, required this.bookIds});

  final int revision;
  final List<int> bookIds;
}

class OptimisticBookOrders
    extends Notifier<Map<BookReadingState, OptimisticBookOrder>> {
  int _revision = 0;

  @override
  Map<BookReadingState, OptimisticBookOrder> build() => const {};

  OptimisticBookOrder setOrder(BookReadingState lane, List<int> bookIds) {
    final order = OptimisticBookOrder(
      revision: ++_revision,
      bookIds: List.unmodifiable(bookIds),
    );
    state = {...state, lane: order};
    return order;
  }

  void clear(BookReadingState lane, int revision) {
    if (state[lane]?.revision != revision) return;
    state = {...state}..remove(lane);
  }
}

List<NxBook> booksInLaneOrder(
  List<NxBook> books,
  BookReadingState lane,
  List<int>? preferredOrder,
) {
  final result = sortedBooksForState(books, lane);
  if (preferredOrder == null) return result;
  final positions = <int, int>{
    for (var i = 0; i < preferredOrder.length; i++) preferredOrder[i]: i,
  };
  result.sort((a, b) {
    final aPosition = positions[a.id];
    final bPosition = positions[b.id];
    if (aPosition != null && bPosition != null) {
      return aPosition.compareTo(bPosition);
    }
    if (aPosition != null) return -1;
    if (bPosition != null) return 1;
    return compareBooksInLane(a, b);
  });
  return result;
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

class SelectedTopicTag extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? value) {
    state = value?.trim().isEmpty ?? true ? null : value!.trim();
  }
}

class BookCollectionState extends Notifier<BookReadingState> {
  @override
  BookReadingState build() => BookReadingState.toRead;

  void set(BookReadingState value) {
    if (value == BookReadingState.reading) return;
    state = value;
  }
}
