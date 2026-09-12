import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_books/companion/reading_companion.dart';
import 'package:nx_books/companion/reading_route.dart';
import 'package:nx_books/epub/epub_reader_page.dart';
import 'package:nx_documents/nx_documents.dart';

void main() {
  testWidgets(
    'summary → chapter → EPUB → back restores identity and stable host',
    (tester) async {
      final container = ProviderContainer();
      final router = GoRouter(
        initialLocation: '/books',
        routes: [
          GoRoute(
            path: '/books',
            builder: (_, __) => const Scaffold(body: Text('Library')),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const Scaffold(body: Text('Settings')),
          ),
          ReadingRoute(
            path: '/books/:id/notes',
            readingIdentity: (s) => DocumentIdentity(
              id: int.parse(s.pathParameters['id']!),
              modelType: 'Book',
            ),
            builder: (_, __) => const Scaffold(body: Text('Book summary')),
          ),
          ReadingRoute(
            path: '/documents/:id/notes',
            readingIdentity: (s) => DocumentIdentity(
              id: int.parse(s.pathParameters['id']!),
              modelType: 'Document',
            ),
            builder: (_, __) => const Scaffold(body: Text('Chapter summary')),
          ),
          ReadingRoute(
            path: '/books/:id/reader',
            isEpub: true,
            readingIdentity: (s) => DocumentIdentity(
              id: int.parse(s.pathParameters['id']!),
              modelType: 'EpubBook',
            ),
            builder: (_, state) => Consumer(
              builder: (_, ref, __) {
                ref.watch(readerPassageProvider(state.pageKey));
                if (state.extra == 'fail') {
                  return EpubReaderPage(
                    path: 'missing.epub',
                    title: 'Failed EPUB',
                    loadBook: (_) async => throw StateError('Unreadable EPUB'),
                  );
                }
                return const Scaffold(body: Text('EPUB'));
              },
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            builder: (_, child) => ReadingCompanionHost(
              router: router,
              enabled: true,
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final hostState = tester.state(find.byType(ReadingCompanion));
      final navigatorState = router.routerDelegate.navigatorKey.currentState;
      ReadingCompanion companion() =>
          tester.widget<ReadingCompanion>(find.byType(ReadingCompanion));
      void check(String? type, int? id) {
        expect(companion().identity?.modelType, type);
        expect(companion().identity?.id, id);
        expect(
          find.byTooltip('Reading companion'),
          type == null ? findsNothing : findsOneWidget,
        );
        if (type != null) {
          expect(
            tester
                .widget<FloatingActionButton>(find.byType(FloatingActionButton))
                .heroTag,
            isNull,
            reason:
                'The shared overlay must not disappear into a route hero flight',
          );
        }
        expect(tester.state(find.byType(ReadingCompanion)), same(hostState));
        expect(
          router.routerDelegate.navigatorKey.currentState,
          same(navigatorState),
        );
        expect(tester.takeException(), isNull);
      }

      check(null, null);
      router.push('/books/4541/notes');
      await tester.pumpAndSettle();
      check('Book', 4541);
      router.push('/documents/5435/notes');
      await tester.pumpAndSettle();
      check('Document', 5435);
      // Separate instances of the same EPUB keep independent passages.
      router.push('/books/4541/reader');
      await tester.pumpAndSettle();
      final firstKey = router.state.pageKey;
      final firstPassage = container.read(readerPassageProvider(firstKey));
      firstPassage.value = 'First reader';
      router.push('/books/4541/reader');
      await tester.pumpAndSettle();
      expect(router.state.pageKey, isNot(firstKey));
      expect(companion().passage?.value, isEmpty);
      router.pop();
      await tester.pumpAndSettle();
      expect(companion().passage, same(firstPassage));
      expect(companion().passage?.value, 'First reader');
      router.pop();
      await tester.pumpAndSettle();
      check('Document', 5435);
      // A real reader parsing failure leaves the underlying chapter intact.
      router.push('/books/4541/reader', extra: 'fail');
      await tester.pumpAndSettle();
      check('EpubBook', 4541);
      expect(find.text('Failed EPUB'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      check('Document', 5435);
      for (var i = 0; i < 3; i++) {
        router.push('/books/4541/reader');
        await tester.pumpAndSettle();
        check('EpubBook', 4541);
        final passage = container.read(
          readerPassageProvider(router.state.pageKey),
        );
        expect(passage.value, isEmpty);
        passage.value = 'Reading passage $i';
        await tester.pumpAndSettle();
        expect(companion().passage?.value, 'Reading passage $i');
        // Exercise the reader's Navigator.pop back button, not just router.pop.
        Navigator.of(tester.element(find.text('EPUB'))).pop();
        await tester.pumpAndSettle();
        check('Document', 5435);
        expect(companion().passage, isNull);
        expect(find.text('Chapter summary'), findsOneWidget);
      }
      router.pop();
      await tester.pumpAndSettle();
      check('Book', 4541);
      router.push('/settings');
      await tester.pumpAndSettle();
      check(null, null);
      router.pop();
      await tester.pumpAndSettle();
      check('Book', 4541);
      router.pop();
      await tester.pumpAndSettle();
      check(null, null);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      container.dispose();
    },
  );
}
