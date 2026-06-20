import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_books/core/theme/app_theme.dart';
import 'package:nx_books/data/providers.dart';
import 'package:nx_books/domain/book/book.dart';
import 'package:nx_books/domain/book/book_repository.dart';
import 'package:nx_books/features/books/books_shell.dart';

void main() {
  test('notesUriForBook opens the matching document in nx_notes', () {
    final uri = notesUriForBook(
      4195,
      Uri.parse('https://nexus.example.com/books/'),
    );

    expect(uri.toString(), 'https://nexus.example.com/docs/4195');
  });

  test('sortedBooksForState sorts by rank, updated_at desc, then title', () {
    final rows = [
      _book(1, 'Beta', BookReadingState.reading, rank: 1),
      _book(2, 'Alpha', BookReadingState.reading, rank: 0),
      _book(3, 'Gamma', BookReadingState.reading, rank: null),
    ];

    expect(
      sortedBooksForState(
        rows,
        BookReadingState.reading,
      ).map((book) => book.id),
      [2, 1, 3],
    );
  });

  testWidgets('bookshelf groups books into desktop lanes', (tester) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeBookRepository([
      _book(1, 'Reading rank one', BookReadingState.reading, rank: 1),
      _book(
        2,
        'Reading rank zero',
        BookReadingState.reading,
        rank: 0,
        tags: const ['startup', 'strategy'],
      ),
      _book(3, 'Queued book', BookReadingState.toRead, rank: 0),
      _book(4, 'Finished book', BookReadingState.read, rank: 0),
    ]);

    await tester.pumpWidget(_testApp(repo));
    await tester.pumpAndSettle();

    expect(find.text('Reading'), findsWidgets);
    expect(find.text('To Read'), findsWidgets);
    expect(find.text('Read'), findsWidgets);
    expect(find.text('Queued book'), findsOneWidget);
    expect(find.text('Finished book'), findsOneWidget);
    expect(find.text('startup'), findsWidgets);
    expect(find.text('strategy'), findsWidgets);

    final first = tester.getTopLeft(find.byKey(const ValueKey('book-card-2')));
    final second = tester.getTopLeft(find.byKey(const ValueKey('book-card-1')));
    expect(first.dy, lessThan(second.dy));
  });

  test('changing state appends the book to the target lane', () async {
    final repo = _FakeBookRepository([
      _book(1, 'One', BookReadingState.reading, rank: 0),
      _book(2, 'Two', BookReadingState.toRead, rank: 0),
      _book(3, 'Three', BookReadingState.toRead, rank: 1),
    ]);
    final container = ProviderContainer(
      overrides: [bookRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await container.read(booksProvider.future);
    await container
        .read(bookMutationControllerProvider)
        .changeState(repo.rows.first, BookReadingState.toRead);

    final moved = repo.rows.singleWhere((book) => book.id == 1);
    expect(moved.readingState, BookReadingState.toRead);
    expect(moved.rank, 2);
  });

  test('moving within a lane rewrites affected ranks', () async {
    final repo = _FakeBookRepository([
      _book(1, 'One', BookReadingState.reading, rank: 0),
      _book(2, 'Two', BookReadingState.reading, rank: 1),
      _book(3, 'Three', BookReadingState.reading, rank: 2),
    ]);
    final container = ProviderContainer(
      overrides: [bookRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await container.read(booksProvider.future);
    await container
        .read(bookMutationControllerProvider)
        .moveWithinLane(repo.rows.first, 1);

    expect(repo.rows.singleWhere((book) => book.id == 2).rank, 0);
    expect(repo.rows.singleWhere((book) => book.id == 1).rank, 1);
    expect(repo.rows.singleWhere((book) => book.id == 3).rank, 2);
  });
}

Widget _testApp(BookRepository repo) {
  return ProviderScope(
    overrides: [bookRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(theme: buildAppTheme(), home: const BooksRootShell()),
  );
}

NxBook _book(
  int id,
  String title,
  BookReadingState state, {
  required int? rank,
  List<String> tags = const [],
}) {
  final now = DateTime(2026, 6, 19, 12, 0).subtract(Duration(minutes: id));
  return NxBook(
    id: id,
    title: title,
    description: '',
    tags: tags,
    readingState: state,
    rank: rank,
    wordCount: id * 100,
    updatedAt: now,
    updatedLabel: '${id}m ago',
  );
}

class _FakeBookRepository implements BookRepository {
  _FakeBookRepository(List<NxBook> rows) : rows = [...rows];

  final List<NxBook> rows;
  int _nextId = 1000;

  @override
  Future<NxBook> createBook({String? title}) async {
    final nextRank =
        rows
            .where((book) => book.readingState == BookReadingState.toRead)
            .map((book) => book.rank ?? -1)
            .fold<int>(-1, (max, rank) => rank > max ? rank : max) +
        1;
    final book = _book(
      _nextId++,
      title?.trim().isEmpty ?? true ? 'Untitled book' : title!.trim(),
      BookReadingState.toRead,
      rank: nextRank,
    );
    rows.add(book);
    return book;
  }

  @override
  Future<List<NxBook>> listBooks() async => [...rows];

  @override
  Future<List<String>> listTopicTags() async => const [
    'Business',
    'Product',
    'Strategy',
  ];

  @override
  Future<void> updateBookRank({required int id, required int rank}) async {
    final index = rows.indexWhere((book) => book.id == id);
    rows[index] = rows[index].copyWith(rank: rank);
  }

  @override
  Future<void> updateBookState({
    required int id,
    required BookReadingState state,
    required int rank,
  }) async {
    final index = rows.indexWhere((book) => book.id == id);
    rows[index] = rows[index].copyWith(readingState: state, rank: rank);
  }

  @override
  Future<void> updateBookTopicTags({
    required int id,
    required List<String> tags,
  }) async {
    final index = rows.indexWhere((book) => book.id == id);
    rows[index] = rows[index].copyWith(tags: tags);
  }
}
