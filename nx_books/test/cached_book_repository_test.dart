import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_books/data/offline/cached_book_repository.dart';
import 'package:nx_books/data/providers.dart';
import 'package:nx_books/domain/book/book.dart';
import 'package:nx_books/domain/book/book_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'cached reads finish while the remote is stalled, including after restart',
    () async {
      final remote = _Remote();
      final repository = CachedBookRepository(remote: remote, accountKey: 'a');
      await repository.refreshBooks();
      await repository.refreshTopicTags();
      remote.gate = Completer<List<NxBook>>();
      final restarted = CachedBookRepository(remote: remote, accountKey: 'a');
      expect(
        (await restarted.listBooks().timeout(
          const Duration(seconds: 1),
        )).single.title,
        'Book',
      );
      expect(
        (await restarted.listBooks()).single.bookLink,
        '/books/1-book.epub',
      );
      expect(await restarted.listTopicTags(), ['Topic']);
      expect(remote.reads, 1);
    },
  );

  test('an empty downloaded bookshelf is a valid cache', () async {
    final remote = _Remote()..books = [];
    final repository = CachedBookRepository(remote: remote, accountKey: 'a');
    await repository.refreshBooks();
    remote.fail = true;
    expect(await repository.listBooks(), isEmpty);
    expect(remote.reads, 1);
  });

  test('network-first configuration preserves web refresh behavior', () async {
    final remote = _Remote();
    final repository = CachedBookRepository(
      remote: remote,
      accountKey: 'a',
      cacheFirst: false,
    );
    await repository.listBooks();
    remote.books = [remote.books.single.copyWith(title: 'Updated')];
    expect((await repository.listBooks()).single.title, 'Updated');
    expect(remote.reads, 2);
  });

  test(
    'failed explicit refresh retains cache and does not report success',
    () async {
      final remote = _Remote();
      final repository = CachedBookRepository(remote: remote, accountKey: 'a');
      await repository.refreshBooks();
      remote.fail = true;
      await expectLater(repository.refreshBooks(), throwsStateError);
      expect((await repository.listBooks()).single.title, 'Book');
      final otherAccount = CachedBookRepository(
        remote: remote,
        accountKey: 'b',
      );
      await expectLater(otherAccount.listBooks(), throwsStateError);
    },
  );

  test('successful online mutations are reflected by the next read', () async {
    final remote = _Remote();
    final repository = CachedBookRepository(remote: remote, accountKey: 'a');
    await repository.refreshBooks();
    await repository.updateBookRank(id: 1, rank: 4);
    expect((await repository.listBooks()).single.rank, 4);
  });

  test('refresh publishes changed cache to the bookshelf provider', () async {
    final remote = _Remote();
    final repository = CachedBookRepository(remote: remote, accountKey: 'a');
    await repository.refreshBooks();
    final container = ProviderContainer(
      overrides: [bookRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(booksProvider, (_, __) {});
    addTearDown(subscription.close);
    expect((await container.read(booksProvider.future)).single.title, 'Book');
    remote.books = [remote.books.single.copyWith(title: 'Updated')];
    await container.read(refreshBookCatalogProvider)();
    expect(
      (await container.read(booksProvider.future)).single.title,
      'Updated',
    );
  });

  test(
    'a refresh started before a mutation cannot replace its newer cache',
    () async {
      final remote = _Remote();
      final repository = CachedBookRepository(remote: remote, accountKey: 'a');
      await repository.refreshBooks();
      final oldBooks = [...remote.books];
      final gate = remote.gate = Completer<List<NxBook>>();
      final oldRefresh = repository.refreshBooks();
      await repository.updateBookRank(id: 1, rank: 4);
      remote.gate = null;
      expect((await repository.listBooks()).single.rank, 4);
      gate.complete(oldBooks);
      await oldRefresh;
      expect((await repository.listBooks()).single.rank, 4);
    },
  );
}

class _Remote implements BookRepository {
  int reads = 0;
  bool fail = false;
  Completer<List<NxBook>>? gate;
  List<NxBook> books = [
    NxBook(
      id: 1,
      title: 'Book',
      description: '',
      author: '',
      link: '',
      bookLink: '/books/1-book.epub',
      tags: ['Topic'],
      readingState: BookReadingState.reading,
      rank: 0,
      totalChapters: 3,
      currentChapter: 1,
      wordCount: 10,
      updatedAt: DateTime.utc(2026),
      updatedLabel: '',
    ),
  ];
  @override
  Future<List<NxBook>> listBooks() async {
    reads++;
    if (fail) throw StateError('offline');
    return gate?.future ?? Future.value(books);
  }

  @override
  Future<List<String>> listTopicTags() async => ['Topic'];
  @override
  Future<void> updateBookRank({required int id, required int rank}) async {
    books = [books.single.copyWith(rank: rank)];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
