import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/browser/language/language_page.dart';
import 'card_search_test.dart' show card;

class Library implements CardLibrary {
  Library(this.cards);
  List<StudyCard> cards;
  final changes = <(int, LearningStatus)>[];
  final failures = <int>{};
  @override
  Future<void> setLearningStatus(StudyCard card, LearningStatus status) async {
    if (failures.contains(card.id)) throw StateError('offline');
    changes.add((card.id, status));
    cards = [
      for (final existing in cards)
        existing.id == card.id
            ? existing.copyWith(learningStatus: status)
            : existing,
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> showCollection(WidgetTester tester, Library library) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cardLibraryProvider.overrideWithValue(library),
        cardsCollectionProvider.overrideWith(
          (ref, source) => Stream.value(CardsDashboard(cards: library.cards)),
        ),
        cardsInvalidationProvider.overrideWith(
          (ref) =>
              () => ref.invalidate(cardsCollectionProvider),
        ),
      ],
      child: const MaterialApp(
        home: LanguageCategoryPage(
          category: 'All',
          allCards: true,
          language: 'Chinese',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Add selects cards and sends only the selection directly to Current',
    (tester) async {
      final library = Library([
        for (var i = 1; i <= 3; i++) card(i, LearningStatus.future),
      ]);
      await showCollection(tester, library);
      await tester.tap(find.byKey(const ValueKey('open-backlog')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bulk-select')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('select-card-1')));
      await tester.tap(find.byKey(const ValueKey('select-card-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send to Current'));
      await tester.pumpAndSettle();
      expect(library.changes, [
        (1, LearningStatus.recall),
        (3, LearningStatus.recall),
      ]);
      expect(library.cards[1].learningStatus, LearningStatus.future);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Failed additions stay selected and retry excludes successes', (
    tester,
  ) async {
    final library = Library([
      card(1, LearningStatus.future),
      card(2, LearningStatus.future),
    ])..failures.add(2);
    await showCollection(tester, library);
    await tester.tap(find.byKey(const ValueKey('open-backlog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bulk-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('select-card-1')));
    await tester.tap(find.byKey(const ValueKey('select-card-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send to Current'));
    await tester.pumpAndSettle();
    expect(library.changes, [(1, LearningStatus.recall)]);
    expect(find.text('1 selected'), findsOneWidget);
    library.failures.clear();
    await tester.tap(find.text('Send to Current'));
    await tester.pumpAndSettle();
    expect(library.changes, [
      (1, LearningStatus.recall),
      (2, LearningStatus.recall),
    ]);
    expect(tester.takeException(), isNull);
  });
}
