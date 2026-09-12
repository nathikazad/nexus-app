import 'package:epub_view/epub_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_books/data/providers.dart';
import 'package:nx_books/data/book/epub_progress_repository.dart';
import 'package:nx_books/domain/book/book.dart';
import 'package:nx_books/epub/epub_reader_page.dart';
import 'package:nx_books/epub/epub_route_page.dart';
import 'package:nx_books/epub/retained_epub.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'epub_reader_test.dart' show sampleEpub;

class _Remote implements EpubProgressRemote {
  @override
  Future<Map<String, dynamic>?> load(int id) async => null;
  @override
  Future<void> save(int id, Map<String, dynamic> value) async {}
}

NxBook book(int id) => NxBook(
  id: id,
  title: 'Book $id',
  description: '',
  author: '',
  link: '',
  bookFileHash: 'hash$id',
  tags: const [],
  readingState: BookReadingState.reading,
  rank: 1,
  wordCount: 1,
  updatedAt: DateTime(2026),
  updatedLabel: '',
);

void main() {
  testWidgets(
    'one warm renderer survives hiding, jumps, and is released on book change',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final document = await EpubReader.readBook(sampleEpub());
      final progress = EpubProgressRepository(
        account: 'test',
        remote: _Remote(),
      );
      final container = ProviderContainer(
        overrides: [epubProgressRepositoryProvider.overrideWithValue(progress)],
      );
      EpubRouteRequest request(int id, {int? block}) => EpubRouteRequest(
        book: book(id),
        path: '/not-read-again.epub',
        loadedBook: document,
        saveProgress: false,
        savedPosition: block == null
            ? null
            : {'location': EpubLocation(block).toJson()},
      );
      Future<void> show(
        EpubRouteRequest? request, {
        int bookId = 1,
        bool keep = true,
        String key = 'reader1',
      }) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: RetainedEpubHost(
                request: request,
                bookId: bookId,
                keepSession: keep,
                account: 'test',
                routeKey: ValueKey(key),
                onBack: () {},
                child: const Scaffold(body: Text('Summary')),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await show(request(1));
      final readerFinder = find.byType(EpubReaderPage, skipOffstage: false);
      final state = tester.state(readerFinder);
      final rendererState = tester.state(
        find.byType(EpubView, skipOffstage: false),
      );
      await show(null);
      expect(find.byType(EpubReaderPage), findsNothing);
      expect(tester.state(readerFinder), same(state));
      expect(
        container.read(activeEpubCacheProvider).forBook(book(1)),
        isNotNull,
      );
      await show(request(1, block: 3), key: 'reader2');
      expect(tester.state(readerFinder), same(state));
      expect(tester.state(find.byType(EpubView)), same(rendererState));
      expect(find.text('Second chapter'), findsWidgets);
      await show(null);
      await show(request(1), key: 'reader3');
      expect(tester.state(readerFinder), same(state));
      expect(find.text('Second chapter'), findsWidgets);
      await show(null, bookId: 2);
      expect(readerFinder, findsNothing);
      expect(state.mounted, isFalse);
      expect(container.read(activeEpubCacheProvider).current, isNull);
      await show(request(2), bookId: 2);
      expect(readerFinder, findsOneWidget);
      expect(tester.state(readerFinder), isNot(same(state)));
      await show(null, bookId: 2);
      tester.binding.handleMemoryPressure();
      await tester.pumpAndSettle();
      expect(readerFinder, findsNothing);
      expect(container.read(activeEpubCacheProvider).current, isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      progress.dispose();
    },
  );
}
