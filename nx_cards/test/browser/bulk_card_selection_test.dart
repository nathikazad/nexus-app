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
  Future<void> setLearningStatus(
    StudyCard card,
    LearningStatus status, {
    bool? spokenOnly,
  }) async {
    if (failures.contains(card.id)) throw StateError('offline');
    changes.add((card.id, status));
    cards = [
      for (final existing in cards)
        existing.id == card.id
            ? existing.copyWith(
                learningStatus: status,
                content:
                    existing.content is LanguageCardContent &&
                        spokenOnly != null
                    ? (existing.content as LanguageCardContent).copyWith(
                        spokenOnly: spokenOnly,
                      )
                    : existing.content,
              )
            : existing,
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> showCollection(
  WidgetTester tester,
  Library library, {
  double width = 390,
  double scale = 1,
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(Size(width, 900));
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
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const LanguageCategoryPage(
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
  testWidgets('unchecked bulk add preserves an existing spoken-only choice', (
    tester,
  ) async {
    final original = card(1, LearningStatus.future);
    final library = Library([
      original.copyWith(
        content: (original.content as LanguageCardContent).copyWith(
          spokenOnly: true,
        ),
      ),
    ]);
    await showCollection(tester, library);
    await tester.tap(find.byKey(const ValueKey('open-backlog')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('spoken-only-1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bulk-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('select-card-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bulk-move')));
    await tester.pumpAndSettle();
    expect(library.cards.single.spokenOnly, isTrue);
    expect(library.cards.single.learningStatus, LearningStatus.recall);
    expect(tester.takeException(), isNull);
  });

  for (final (width, scale) in [(390.0, 1.0), (320.0, 1.7), (1024.0, 1.0)]) {
    testWidgets(
      'spoken-only bulk selection and list badge at $width / $scale',
      (tester) async {
        final library = Library([
          card(1, LearningStatus.future),
          card(2, LearningStatus.future),
        ]);
        await showCollection(tester, library, width: width, scale: scale);
        await tester.tap(find.byKey(const ValueKey('open-backlog')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('bulk-select')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('spoken-only-2')), findsNothing);
        final flag = find.byKey(const ValueKey('bulk-spoken-only'));
        expect(tester.widget<Checkbox>(flag).value, isFalse);
        await tester.tap(find.byKey(const ValueKey('select-card-1')));
        await tester.tap(flag);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('bulk-move')));
        await tester.pumpAndSettle();
        expect(library.cards[0].spokenOnly, isTrue);
        expect(library.cards[0].learningStatus, LearningStatus.recall);
        expect(library.cards[1].spokenOnly, isFalse);
        expect(library.cards[1].learningStatus, LearningStatus.future);
        await tester.tap(find.byKey(const ValueKey('bulk-select')));
        await tester.pumpAndSettle();
        expect(tester.widget<Checkbox>(flag).value, isFalse);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('spoken-only-1')), findsOneWidget);
        expect(find.byTooltip('Spoken only'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

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
      expect(library.cards.every((card) => !card.spokenOnly), isTrue);
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
    await tester.tap(find.byKey(const ValueKey('bulk-spoken-only')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send to Current'));
    await tester.pumpAndSettle();
    expect(library.changes, [(1, LearningStatus.recall)]);
    expect(find.text('1 selected'), findsOneWidget);
    expect(library.cards[0].spokenOnly, isTrue);
    expect(library.cards[1].spokenOnly, isFalse);
    expect(
      tester
          .widget<Checkbox>(find.byKey(const ValueKey('bulk-spoken-only')))
          .value,
      isTrue,
    );
    library.failures.clear();
    await tester.tap(find.text('Send to Current'));
    await tester.pumpAndSettle();
    expect(library.changes, [
      (1, LearningStatus.recall),
      (2, LearningStatus.recall),
    ]);
    expect(library.cards.every((card) => card.spokenOnly), isTrue);
    expect(tester.takeException(), isNull);
  });
}
