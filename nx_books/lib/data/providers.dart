import 'dart:async';
import 'book/epub_progress_repository.dart';
import 'offline/reading_history_store.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:nx_offline/nx_offline_storage.dart';
import 'package:nx_offline/nx_offline.dart' as offline;
import 'package:nx_books/data/offline/books_hash_sync.dart';
import 'package:nx_books/data/offline/books_sync_store.dart';
import 'package:nx_books/data/book/kgql_books_sync_transport.dart';
import 'package:nx_books/data/offline/preferences_download_report_store.dart';
import 'package:nx_books/data/offline/book_file_cache.dart';
import 'package:nx_books/data/offline/preferences_book_file_report_store.dart';
import 'package:nx_books/domain/book/book_file_report.dart';
import 'package:nx_books/domain/book/download_report.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_books/data/book/kgql_book_repository.dart';
import 'package:nx_books/data/offline/cached_book_repository.dart';
import 'package:nx_books/data/offline/cached_document_repository.dart';
import 'package:nx_books/domain/book/book.dart';
import 'package:nx_books/domain/book/book_repository.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/app_sync.dart' as app_sync;
import 'package:nx_db/riverpod.dart';
import 'package:nx_documents/nx_documents.dart';

final booksFileLibraryProvider = Provider<FileLibrary?>((ref) {
  if (!offline.AppDataPolicy.current.storesOfflineData) return null;
  final user = ref.watch(authProvider).value;
  if (user == null) return null;
  final library = FileLibrary.application(
    'nx_books:nexus-primary:${user.userId}',
  );
  ref.onDispose(() => unawaited(library.close()));
  return library;
});

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  final userId = ref.watch(authProvider).value?.userId ?? 'last-session';
  final remote = KgqlBookRepository(client: ref.watch(graphqlClientProvider));
  return offline.AppDataPolicy.current.select<BookRepository>(
    web: () => remote,
    native: () => CachedBookRepository(
      remote: remote,
      accountKey: userId,
      library: ref.watch(booksFileLibraryProvider),
    ),
  );
});

final epubProgressRepositoryProvider = Provider<EpubProgressRepository>((ref) {
  final user = ref.watch(authProvider).value;
  final repository = EpubProgressRepository(
    persistData: offline.AppDataPolicy.current.storesOfflineData,
    account: '${user?.preset.key}:${user?.userId}',
    remote: KgqlEpubProgressRemote(ref.watch(graphqlClientProvider)),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final bookDocumentRepositoryProvider =
    Provider<CachedDocumentContentRepository>((ref) {
      final userId = ref.watch(authProvider).value?.userId ?? 'last-session';
      return CachedDocumentContentRepository(
        persistData: offline.AppDataPolicy.current.storesOfflineData,
        remote: KgqlDocumentContentRepository(
          client: ref.watch(graphqlClientProvider),
          auditSourceKind: 'nx_books',
        ),
        accountKey: userId,
        library: ref.watch(booksFileLibraryProvider),
      );
    });

final offlineBookHydrationEnabledProvider = Provider<bool>((ref) => true);
// An interface can prove disconnection, but only the request can prove that
// the service is reachable. Failed requests are handled by the retry supervisor.
final booksNetworkAvailableProvider = Provider<Future<bool> Function()>((ref) {
  return () async => (await Connectivity().checkConnectivity()).any(
    (value) => value != ConnectivityResult.none,
  );
});
final readingHistoryStoreProvider = Provider<ReadingHistoryStore?>((ref) {
  final library = ref.watch(booksFileLibraryProvider);
  return library == null ? null : ReadingHistoryStore(library);
});

final downloadReportStoreProvider = Provider<DownloadReportStore?>((ref) {
  final user = ref.watch(authProvider).value;
  if (!offline.AppDataPolicy.current.storesOfflineData || user == null)
    return null;
  return PreferencesDownloadReportStore('nexus-primary:${user.userId}');
});

final downloadReportProvider = FutureProvider<DownloadReport?>((ref) async {
  return ref.watch(downloadReportStoreProvider)?.load();
});

final bookFileReportStoreProvider = Provider<BookFileReportStore?>((ref) {
  final user = ref.watch(authProvider).value;
  if (!offline.AppDataPolicy.current.storesOfflineData || user == null)
    return null;
  return PreferencesBookFileReportStore('nexus-primary:${user.userId}');
});

final bookFileReportProvider = FutureProvider<BookFileReport?>((ref) async {
  return ref.watch(bookFileReportStoreProvider)?.load();
});

final bookFileCacheProvider = Provider<BookFileCache?>((ref) {
  final user = ref.watch(authProvider).value;
  final client = ref.watch(nexusHttpClientProvider);
  if (!offline.AppDataPolicy.current.storesOfflineData ||
      user == null ||
      client == null)
    return null;
  return BookFileCache(
    accountKey: 'nexus-primary:${user.userId}',
    origin: Uri.parse(resolve(user.preset).imageHttp),
    client: client,
    files: BinaryContentFiles.application(
      'nx_books:nexus-primary:${user.userId}',
    ),
    reportStore: ref.watch(bookFileReportStoreProvider),
    onReportChanged: () {
      if (ref.mounted) ref.invalidate(bookFileReportProvider);
    },
  );
});

final refreshBookCatalogProvider = Provider<Future<void> Function()>((ref) {
  final repository = ref.watch(bookRepositoryProvider);
  return () async {
    if (repository case final BookCatalogRefresh refresh) {
      await Future.wait([
        refresh.refreshBooks().then((_) {
          if (ref.mounted) ref.invalidate(booksProvider);
        }),
        refresh.refreshTopicTags().then((_) {
          if (ref.mounted) ref.invalidate(topicTagsProvider);
        }),
      ]);
    } else if (ref.mounted) {
      ref.invalidate(booksProvider);
      ref.invalidate(topicTagsProvider);
    }
  };
});

final booksLibrarySyncProvider =
    Provider<offline.SyncSupervisor<DocumentIdentity>?>((ref) {
      if (!offline.AppDataPolicy.current.storesOfflineData ||
          !ref.watch(offlineBookHydrationEnabledProvider) ||
          ref.watch(authProvider).value == null) {
        return null;
      }
      final client = ref.watch(graphqlClientProvider);
      final histories = ref.watch(readingHistoryStoreProvider);
      final hasNetwork = ref.watch(booksNetworkAvailableProvider);
      final library = ref.watch(booksFileLibraryProvider);
      final catalog = ref.watch(bookRepositoryProvider);
      final epubProgress = ref.watch(epubProgressRepositoryProvider);
      if (library == null ||
          histories == null ||
          catalog is! CachedBookRepository) {
        return null;
      }
      final sync = offline.SyncSupervisor<DocumentIdentity>(
        retryDelay: const Duration(seconds: 5),
        prepare: () async {
          if (!await hasNetwork()) {
            throw StateError('Offline. Sync will retry automatically.');
          }
          unawaited(epubProgress.flush().catchError((Object _) {}));
        },
        reconciler: BooksHashPull(
          transport: KgqlBooksSyncTransport(client),
          store: BooksSyncStore(
            library,
            ref.watch(bookDocumentRepositoryProvider),
            histories,
            catalog,
          ),
          reportStore: ref.watch(downloadReportStoreProvider),
          onChanged: () {
            if (ref.mounted) {
              ref.invalidate(downloadReportProvider);
            }
          },
          onCatalogChanged: () {
            if (ref.mounted) {
              ref.invalidate(booksProvider);
              ref.invalidate(topicTagsProvider);
            }
          },
          pullBookFiles: () async {
            final cache = ref.read(bookFileCacheProvider);
            if (cache != null) {
              await cache.synchronize(
                await ref.read(bookRepositoryProvider).listBooks(),
              );
            }
          },
        ),
      );
      ref.onDispose(() => unawaited(sync.close()));
      return sync;
    });

final booksLifecycleSyncProvider = Provider<offline.OfflineSynchronize?>((ref) {
  if (!offline.AppDataPolicy.current.storesOfflineData) {
    if (!app_sync.appStateSyncEnabled || ref.watch(authProvider).value == null)
      return null;
    final client = app_sync.AppSyncClient(
      ref.watch(graphqlClientProvider),
      'books',
    );
    final refresh = ref.watch(refreshBookCatalogProvider);
    return (_) => client.refreshIfChanged(refresh);
  }
  final sync = ref.watch(booksLibrarySyncProvider);
  return sync?.requestFull;
});

final booksSyncStatusProvider = StreamProvider<offline.SyncStatus>((
  ref,
) async* {
  final sync = ref.watch(booksLibrarySyncProvider);
  if (sync == null) {
    yield const offline.SyncStatus.idle();
    return;
  }
  yield sync.status;
  yield* sync.statusChanges;
});

final booksOnlineChangesProvider = Provider<Stream<bool>?>((ref) {
  if (ref.watch(booksLibrarySyncProvider) == null) return null;
  return Connectivity().onConnectivityChanged
      .map(
        (results) => results.any((result) => result != ConnectivityResult.none),
      )
      .distinct();
});

final booksProvider = FutureProvider<List<NxBook>>((ref) async {
  final books = await ref.watch(bookRepositoryProvider).listBooks();
  return books;
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
