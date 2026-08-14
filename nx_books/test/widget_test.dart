import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_books/core/theme/app_theme.dart';
import 'package:nx_books/data/providers.dart';
import 'package:nx_books/domain/book/book.dart';
import 'package:nx_books/domain/book/book_repository.dart';
import 'package:nx_books/features/books/books_shell.dart';
import 'package:nx_books/features/books/notes/book_notes_page.dart';
import 'package:nx_documents/nx_documents.dart';

void main() {
  test('book notes stay inside the nx_books route tree', () {
    expect(bookNotesPath(4195), '/books/4195/notes');
    expect(bookDetailsPath(4195), '/books/4195/details');
    expect(notesPathForHref('kgql://Document/4209'), '/documents/4209/notes');
    expect(notesPathForHref('kgql://Essay/4210'), '/documents/4210/notes');
    expect(notesPathForHref('https://example.com'), isNull);
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

  test('book progress percent requires current and total chapters', () {
    expect(
      _book(
        1,
        'Progress',
        BookReadingState.reading,
        rank: 0,
        totalChapters: 20,
        currentChapter: 5,
      ).progressPercent,
      25,
    );
    expect(
      _book(
        2,
        'Missing current',
        BookReadingState.reading,
        rank: 0,
        totalChapters: 20,
      ).progressPercent,
      isNull,
    );
    expect(
      _book(
        3,
        'Missing total',
        BookReadingState.reading,
        rank: 0,
        currentChapter: 5,
      ).progressPercent,
      isNull,
    );
  });

  testWidgets('desktop bookshelf keeps reading separate and switches library', (
    tester,
  ) async {
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
        author: 'Example Author',
        link: 'https://www.amazon.com/example/dp/1234567890',
        tags: const ['startup', 'strategy'],
        totalChapters: 20,
        currentChapter: 5,
      ),
      _book(3, 'Queued book', BookReadingState.toRead, rank: 0),
      _book(4, 'Finished book', BookReadingState.read, rank: 0),
    ]);

    await tester.pumpWidget(_testApp(repo));
    await tester.pumpAndSettle();

    expect(find.text('Currently Reading'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('To Read'), findsWidgets);
    expect(find.text('Read'), findsWidgets);
    expect(find.text('Queued book'), findsOneWidget);
    expect(find.text('Finished book'), findsNothing);
    expect(find.text('startup'), findsWidgets);
    expect(find.text('strategy'), findsWidgets);
    expect(find.text('Example Author'), findsWidgets);
    expect(find.text('25%'), findsWidgets);

    final first = tester.getTopLeft(find.byKey(const ValueKey('book-card-2')));
    final second = tester.getTopLeft(find.byKey(const ValueKey('book-card-1')));
    expect(
      first.dy < second.dy || (first.dy == second.dy && first.dx < second.dx),
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('collection-read')));
    await tester.pumpAndSettle();

    expect(find.text('Currently Reading'), findsOneWidget);
    expect(find.text('Queued book'), findsNothing);
    expect(find.text('Finished book'), findsOneWidget);
  });

  testWidgets('mobile bookshelf shows reading above switchable library', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeBookRepository([
      _book(1, 'In progress', BookReadingState.reading, rank: 0),
      _book(2, 'Waiting book', BookReadingState.toRead, rank: 0),
      _book(3, 'Completed book', BookReadingState.read, rank: 0),
    ]);

    await tester.pumpWidget(_testApp(repo));
    await tester.pumpAndSettle();

    expect(find.text('Currently Reading'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('In progress'), findsWidgets);
    expect(find.text('Waiting book'), findsOneWidget);
    expect(find.text('Completed book'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('collection-read')));
    await tester.pumpAndSettle();

    expect(find.text('In progress'), findsWidgets);
    expect(find.text('Waiting book'), findsNothing);
    expect(find.text('Completed book'), findsOneWidget);
  });

  testWidgets('desktop topic dropdown filters one tag at a time', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _FakeBookRepository([
      _book(
        1,
        'Product book',
        BookReadingState.reading,
        rank: 0,
        tags: const ['Product'],
      ),
      _book(
        2,
        'Business book',
        BookReadingState.reading,
        rank: 1,
        tags: const ['Business'],
      ),
    ]);

    await tester.pumpWidget(_testApp(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('desktop-topic-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('topic-filter-Product')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('book-card-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('book-card-2')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('desktop-topic-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('topic-filter-Business')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('book-card-1')), findsNothing);
    expect(find.byKey(const ValueKey('book-card-2')), findsOneWidget);
  });

  testWidgets('mobile topic button opens a single-select filter sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _FakeBookRepository([
      _book(
        1,
        'Product book',
        BookReadingState.reading,
        rank: 0,
        tags: const ['Product'],
      ),
      _book(
        2,
        'Business book',
        BookReadingState.reading,
        rank: 1,
        tags: const ['Business'],
      ),
    ]);

    await tester.pumpWidget(_testApp(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mobile-topic-filter')));
    await tester.pumpAndSettle();
    expect(find.text('Filter by topic'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mobile-topic-choice-Product')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('book-card-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('book-card-2')), findsNothing);
  });

  testWidgets('a book opens its document and the gear opens details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _FakeBookRepository([
      _book(
        1,
        'Book with information',
        BookReadingState.reading,
        rank: 0,
        author: 'An Author',
      ),
    ]);

    await tester.pumpWidget(_testApp(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('book-card-1')));
    await tester.pumpAndSettle();

    expect(find.byType(BookNotesPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('book-details-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('book-details-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('book-detail-1')), findsOneWidget);
    expect(find.text('Book with information'), findsWidgets);
    expect(find.text('An Author'), findsWidgets);
    expect(find.text('Open document'), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('a desktop book also opens its document first', (tester) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _FakeBookRepository([
      _book(1, 'Desktop document', BookReadingState.reading, rank: 0),
    ]);

    await tester.pumpWidget(_testApp(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('book-card-1')));
    await tester.pumpAndSettle();

    expect(find.byType(BookNotesPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('book-details-button')),
      findsOneWidget,
    );
  });

  for (final layout in <String, Size>{
    'mobile': const Size(390, 820),
    'desktop': const Size(1280, 820),
  }.entries) {
    testWidgets(
      '${layout.key} cards reorder after a two-second hold and drag',
      (tester) async {
        tester.view.physicalSize = layout.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = _FakeBookRepository([
          _book(1, 'Drag me', BookReadingState.reading, rank: 0),
          _book(2, 'Middle book', BookReadingState.reading, rank: 1),
          _book(3, 'Drop target', BookReadingState.reading, rank: 2),
        ]);

        await tester.pumpWidget(_testApp(repo));
        await tester.pumpAndSettle();
        final source = find.byKey(const ValueKey('book-card-1'));
        final target = find.byKey(const ValueKey('book-card-3'));
        final gesture = await tester.startGesture(tester.getCenter(source));
        await tester.pump(const Duration(milliseconds: 1999));
        await tester.pump(const Duration(milliseconds: 2));
        final targetRect = tester.getRect(target);
        await gesture.moveTo(
          Offset(targetRect.center.dx, targetRect.bottom - 3),
        );
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();

        final ordered = [...repo.rows]
          ..sort((a, b) => a.rank!.compareTo(b.rank!));
        expect(ordered.map((book) => book.id), [2, 3, 1]);
      },
    );
  }

  testWidgets('mobile drag auto-scrolls faster near the top edge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _FakeBookRepository([
      for (var id = 1; id <= 20; id++)
        _book(id, 'Book $id', BookReadingState.reading, rank: id - 1),
    ]);

    await tester.pumpWidget(_testApp(repo));
    await tester.pumpAndSettle();
    final list = find.byKey(const ValueKey('mobile-books-sections'));
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: list, matching: find.byType(Scrollable)),
    );
    scrollable.position.jumpTo(700);
    await tester.pump();
    final viewport = tester.getRect(list);

    Future<double> scrollFor(Offset edgePosition) async {
      final source = find
          .byType(LongPressDraggable<NxBook>)
          .hitTestable()
          .first;
      final gesture = await tester.startGesture(tester.getCenter(source));
      await tester.pump(const Duration(seconds: 2));
      final before = scrollable.position.pixels;
      await gesture.moveTo(edgePosition);
      await tester.pump(const Duration(milliseconds: 480));
      final distance = before - scrollable.position.pixels;
      await gesture.up();
      await tester.pumpAndSettle();
      return distance;
    }

    final shallowDistance = await scrollFor(
      Offset(viewport.center.dx, viewport.top + 100),
    );
    scrollable.position.jumpTo(700);
    await tester.pump();
    final deepDistance = await scrollFor(
      Offset(viewport.center.dx, viewport.top + 5),
    );

    expect(shallowDistance, greaterThan(0));
    expect(deepDistance, greaterThan(shallowDistance * 2));
  });

  testWidgets('mobile drag auto-scrolls faster near the bottom edge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _FakeBookRepository([
      for (var id = 1; id <= 20; id++)
        _book(id, 'Book $id', BookReadingState.reading, rank: id - 1),
    ]);

    await tester.pumpWidget(_testApp(repo));
    await tester.pumpAndSettle();
    final list = find.byKey(const ValueKey('mobile-books-sections'));
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: list, matching: find.byType(Scrollable)),
    );
    scrollable.position.jumpTo(300);
    await tester.pump();
    final viewport = tester.getRect(list);

    Future<double> scrollFor(Offset edgePosition) async {
      final source = find
          .byType(LongPressDraggable<NxBook>)
          .hitTestable()
          .first;
      final gesture = await tester.startGesture(tester.getCenter(source));
      await tester.pump(const Duration(seconds: 2));
      final before = scrollable.position.pixels;
      await gesture.moveTo(edgePosition);
      await tester.pump(const Duration(milliseconds: 480));
      final distance = scrollable.position.pixels - before;
      await gesture.up();
      await tester.pumpAndSettle();
      return distance;
    }

    final shallowDistance = await scrollFor(
      Offset(viewport.center.dx, viewport.bottom - 100),
    );
    scrollable.position.jumpTo(300);
    await tester.pump();
    final deepDistance = await scrollFor(
      Offset(viewport.center.dx, viewport.bottom - 5),
    );

    expect(shallowDistance, greaterThan(0));
    expect(deepDistance, greaterThan(shallowDistance * 2));
  });

  testWidgets('mobile supports consecutive long-press reorders', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _FakeBookRepository([
      _book(1, 'One', BookReadingState.reading, rank: 0),
      _book(2, 'Two', BookReadingState.reading, rank: 1),
      _book(3, 'Three', BookReadingState.reading, rank: 2),
      _book(4, 'Four', BookReadingState.reading, rank: 3),
    ]);
    await tester.pumpWidget(_testApp(repo));
    await tester.pumpAndSettle();

    Future<void> reorder(
      int sourceId,
      int targetId, {
      required bool after,
    }) async {
      final source = find.byKey(ValueKey('book-card-$sourceId'));
      final target = find.byKey(ValueKey('book-card-$targetId'));
      final gesture = await tester.startGesture(tester.getCenter(source));
      await tester.pump(const Duration(seconds: 2));
      final rect = tester.getRect(target);
      await gesture.moveTo(
        Offset(rect.center.dx, after ? rect.bottom - 3 : rect.top + 3),
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
    }

    await reorder(1, 3, after: true);
    await reorder(1, 2, after: false);

    final ordered = [...repo.rows]..sort((a, b) => a.rank!.compareTo(b.rank!));
    expect(ordered.map((book) => book.id), [1, 2, 3, 4]);
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

  test('drag reorder inserts a book before or after its target', () async {
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
        .reorderWithinLane(
          book: repo.rows.first,
          target: repo.rows.last,
          placeAfter: true,
        );

    final ordered = [...repo.rows]..sort((a, b) => a.rank!.compareTo(b.rank!));
    expect(ordered.map((book) => book.id), [2, 3, 1]);
  });

  testWidgets('drag order updates immediately and rolls back after timeout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final rankGate = Completer<void>();
    final repo = _FakeBookRepository([
      _book(1, 'One', BookReadingState.reading, rank: 0),
      _book(2, 'Two', BookReadingState.reading, rank: 1),
      _book(3, 'Three', BookReadingState.reading, rank: 2),
    ], rankUpdateGate: rankGate);
    await tester.pumpWidget(_testApp(repo));
    await tester.pumpAndSettle();

    final source = find.byKey(const ValueKey('book-card-1'));
    final target = find.byKey(const ValueKey('book-card-3'));
    final gesture = await tester.startGesture(tester.getCenter(source));
    await tester.pump(const Duration(seconds: 2));
    final targetRect = tester.getRect(target);
    await gesture.moveTo(Offset(targetRect.center.dx, targetRect.bottom - 3));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pump();

    expect(
      tester.getTopLeft(find.byKey(const ValueKey('book-card-1'))).dy,
      greaterThan(
        tester.getTopLeft(find.byKey(const ValueKey('book-card-3'))).dy,
      ),
    );

    await tester.pump(const Duration(seconds: 21));
    await tester.pump();

    expect(
      find.text('Could not save the new order. The book was moved back.'),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('book-card-1'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('book-card-2'))).dy),
    );
    rankGate.complete();
    await tester.pump();
  });

  test('updating chapter progress clamps and clears values', () async {
    final repo = _FakeBookRepository([
      _book(
        1,
        'One',
        BookReadingState.reading,
        rank: 0,
        totalChapters: 12,
        currentChapter: 10,
      ),
    ]);
    final container = ProviderContainer(
      overrides: [bookRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await container.read(booksProvider.future);
    await container
        .read(bookMutationControllerProvider)
        .updateChapterProgress(
          repo.rows.first,
          totalChapters: 8,
          currentChapter: 10,
        );

    var row = repo.rows.single;
    expect(row.totalChapters, 8);
    expect(row.currentChapter, 8);

    await container
        .read(bookMutationControllerProvider)
        .updateChapterProgress(
          row,
          totalChapters: null,
          currentChapter: row.currentChapter,
        );

    row = repo.rows.single;
    expect(row.totalChapters, isNull);
    expect(row.currentChapter, isNull);
  });

  test('deleting a book removes it and clears selection', () async {
    final repo = _FakeBookRepository([
      _book(1, 'One', BookReadingState.reading, rank: 0),
      _book(2, 'Two', BookReadingState.reading, rank: 1),
    ]);
    final container = ProviderContainer(
      overrides: [bookRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    container.read(selectedBookIdProvider.notifier).select(1);
    await container.read(booksProvider.future);
    await container
        .read(bookMutationControllerProvider)
        .deleteBook(repo.rows.first);

    expect(repo.rows.map((book) => book.id), [2]);
    expect(container.read(selectedBookIdProvider), isNull);
  });
}

Widget _testApp(BookRepository repo) {
  final router = GoRouter(
    initialLocation: '/books',
    routes: <RouteBase>[
      GoRoute(
        path: '/books',
        builder: (context, state) => const BooksRootShell(),
      ),
      GoRoute(
        path: '/books/:bookId/notes',
        builder: (context, state) =>
            BookNotesPage(bookId: int.parse(state.pathParameters['bookId']!)),
      ),
      GoRoute(
        path: '/books/:bookId/details',
        builder: (context, state) =>
            BookDetailPage(bookId: int.parse(state.pathParameters['bookId']!)),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      bookRepositoryProvider.overrideWithValue(repo),
      bookNotesRepositoryProvider.overrideWithValue(_FakeDocumentRepository()),
      bookNotesImageBaseProvider.overrideWithValue(null),
    ],
    child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
  );
}

class _FakeDocumentRepository implements DocumentContentRepository {
  @override
  Future<DocumentContent?> load(DocumentIdentity identity) async {
    return DocumentContent(
      identity: identity,
      title: 'Book document',
      plainText: '# Book document\nSummary content.',
      jsonDocument: const <String, dynamic>{},
      updatedAt: DateTime.utc(2026),
    );
  }

  @override
  Future<DocumentContent> save(DocumentContent content) async => content;
}

NxBook _book(
  int id,
  String title,
  BookReadingState state, {
  required int? rank,
  List<String> tags = const [],
  int? totalChapters,
  int? currentChapter,
  String author = '',
  String link = '',
}) {
  final now = DateTime(2026, 6, 19, 12, 0).subtract(Duration(minutes: id));
  return NxBook(
    id: id,
    title: title,
    description: '',
    author: author,
    link: link,
    tags: tags,
    readingState: state,
    rank: rank,
    totalChapters: totalChapters,
    currentChapter: currentChapter,
    wordCount: id * 100,
    updatedAt: now,
    updatedLabel: '${id}m ago',
  );
}

class _FakeBookRepository implements BookRepository {
  _FakeBookRepository(List<NxBook> rows, {this.rankUpdateGate})
    : rows = [...rows];

  final List<NxBook> rows;
  final Completer<void>? rankUpdateGate;
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
  Future<void> deleteBook(int id) async {
    rows.removeWhere((book) => book.id == id);
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
    await rankUpdateGate?.future;
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

  @override
  Future<void> updateBookChapterProgress({
    required int id,
    required int? totalChapters,
    required int? currentChapter,
  }) async {
    final index = rows.indexWhere((book) => book.id == id);
    rows[index] = rows[index].copyWith(
      totalChapters: totalChapters,
      clearTotalChapters: totalChapters == null,
      currentChapter: currentChapter,
      clearCurrentChapter: currentChapter == null,
    );
  }
}
