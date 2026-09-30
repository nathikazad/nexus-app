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
    'Upcoming selects a subset beside Practice and moves only that subset to Current',
    (tester) async {
      final library = Library([
        for (var i = 1; i <= 3; i++) card(i, LearningStatus.practice),
      ]);
      await showCollection(tester, library);
      expect(find.byKey(const ValueKey('bulk-select')), findsNothing);
      await tester.tap(find.text('Upcoming  3'));
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.byKey(const ValueKey('bulk-select'))).dx,
        lessThan(
          tester.getCenter(find.widgetWithText(FilledButton, 'Practice')).dx,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('bulk-select')));
      await tester.pumpAndSettle();
      expect(find.text('0 selected'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('bulk-move')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('select-card-1')));
      await tester.tap(find.text('after 3'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
      expect(find.text('Card details'), findsNothing);
      await tester.tap(find.text('Send to Current'));
      await tester.pumpAndSettle();
      expect(library.changes, [
        (1, LearningStatus.recall),
        (3, LearningStatus.recall),
      ]);
      expect(library.cards[1].learningStatus, LearningStatus.practice);
      expect(find.text('Upcoming  1'), findsOneWidget);
      expect(find.text('Current  2'), findsOneWidget);
      expect(find.byKey(const ValueKey('bulk-move')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Backlog moves to Upcoming; failures stay selected for retry without repeating successes',
    (tester) async {
      final library = Library([
        card(1, LearningStatus.future),
        card(2, LearningStatus.future),
      ]);
      library.failures.add(2);
      await showCollection(tester, library);
      await tester.ensureVisible(find.text('Backlog  2'));
      await tester.tap(find.text('Backlog  2'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Practice'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('bulk-select')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('select-card-1')));
      await tester.tap(find.byKey(const ValueKey('select-card-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send to Upcoming'));
      await tester.pumpAndSettle();
      expect(library.changes, [(1, LearningStatus.practice)]);
      expect(find.text('1 selected'), findsOneWidget);
      expect(
        tester
            .widget<Checkbox>(find.byKey(const ValueKey('select-card-2')))
            .value,
        isTrue,
      );
      library.failures.clear();
      await tester.tap(find.text('Send to Upcoming'));
      await tester.pumpAndSettle();
      expect(library.changes, [
        (1, LearningStatus.practice),
        (2, LearningStatus.practice),
      ]);
      expect(find.text('Upcoming  2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Cancel and tab changes discard selection without moving cards', (
    tester,
  ) async {
    final library = Library([
      card(1, LearningStatus.practice),
      card(2, LearningStatus.future),
    ]);
    await showCollection(tester, library);
    await tester.tap(find.text('Upcoming  1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bulk-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('select-card-1')));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bulk-move')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('bulk-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('select-card-1')));
    await tester.tap(find.text('Backlog  1'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bulk-move')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('bulk-select')));
    await tester.pumpAndSettle();
    expect(find.text('0 selected'), findsOneWidget);
    expect(library.changes, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
