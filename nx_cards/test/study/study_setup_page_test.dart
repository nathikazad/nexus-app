import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/scheduling/language_direction.dart';
import 'package:nx_cards/scheduling/review_progression.dart';
import 'package:nx_cards/scheduling/study_scope.dart';
import 'package:nx_cards/study/study_setup_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

StudyCard sample(
  int id,
  int successes, {
  bool active = true,
  bool due = true,
}) => StudyCard(
  id: id,
  content: LanguageCardContent(
    english: 'word $id',
    originalScript: '字$id',
    transliteration: 'zi',
  ),
  suspended: false,
  learningStatus: active ? LearningStatus.learning : LearningStatus.notStarted,
  tags: const {
    'Language': ['Chinese'],
  },
  schedules: {
    for (final cue in StudyCue.activeDirections)
      cue: CardSchedule(
        enabled: true,
        dueAt: DateTime.now().add(Duration(days: due ? -1 : 1)),
        lastReviewedAt: DateTime.utc(2026, 1, 1),
        stability: 1,
        difficulty: 5,
        schedulingState: 'review',
        learningStep: null,
        reviewCount: successes,
        lapseCount: 0,
      ),
  },
  reviewHistory: {
    StudyCue.fromLanguage: [
      for (var i = 0; i < successes; i++)
        CardReview(
          id: '$id-$i',
          reviewedAt: DateTime.utc(2026, 1, i + 1),
          rating: 3,
          elapsedSeconds: 0,
          scheduledSeconds: 0,
        ),
    ],
  },
);
Future<void> showSetup(
  WidgetTester tester, {
  StudyCue cue = StudyCue.fromLanguage,
  List<StudyCard>? studyCards,
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(const Size(900, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final cards =
      studyCards ??
      [
        sample(1, 0),
        sample(2, 1, due: false),
        sample(3, 8),
        sample(4, 10, due: false),
        sample(5, 0, active: false),
      ];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cardsDashboardProvider.overrideWith(
          (ref) => Stream.value(CardsDashboard(cards: cards)),
        ),
        reviewProgressionSettingsProvider.overrideWith(
          (ref) async => const ReviewProgressionSettings(),
        ),
        languageDirectionProvider('Chinese').overrideWith((ref) => cue),
      ],
      child: MaterialApp(
        home: StudySetupPage(
          title: 'Chinese',
          studyScope: const StudyScope(language: 'Chinese'),
          prompts: [],
          studyCards: cards,
          fromLanguage: 'English',
          toLanguage: 'Chinese',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('defaults to Current and Past; recall includes not-due Past', (
    tester,
  ) async {
    await showSetup(tester);
    expect(find.text('3 available'), findsOneWidget);
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Upcoming'))
          .selected,
      isFalse,
    );
    await tester.tap(find.text('Recall').first);
    await tester.pumpAndSettle();
    expect(find.text('3 available'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Upcoming'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Current'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Past'), findsOneWidget);
    expect(find.text('Relearning'), findsNothing);
    expect(find.text('Retained'), findsNothing);
  });
  testWidgets(
    'Past due count follows selected filters and is hidden without Past',
    (tester) async {
      await showSetup(tester);
      expect(find.textContaining('Past cards due'), findsNothing);
      await tester.tap(find.text('Recall').first);
      await tester.pumpAndSettle();
      expect(find.text('Past cards due: 1'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilterChip, 'Past'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Past cards due'), findsNothing);
      await tester.tap(find.widgetWithText(FilterChip, 'Past'));
      await tester.pumpAndSettle();
      final scoreSlider = tester.widgetList<Slider>(find.byType(Slider)).first;
      scoreSlider.onChanged!(70);
      await tester.pumpAndSettle();
      expect(find.text('Past cards due: 0'), findsOneWidget);
      expect(find.text('1 available'), findsOneWidget);
    },
  );
  testWidgets(
    'direction comes from language page; no third cue or local selector',
    (tester) async {
      await showSetup(tester, cue: StudyCue.toLanguage);
      await tester.tap(find.text('Recall').first);
      await tester.pumpAndSettle();
      expect(find.text('No cards match these filters'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilterChip, 'Upcoming'));
      await tester.pumpAndSettle();
      expect(
        find.text('4 available'),
        findsOneWidget,
      ); // all four are untried in reverse
      expect(find.textContaining('Chinese → English'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'Transliteration'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'Chinese'), findsNothing);
    },
  );
  testWidgets('count survives mode changes and clamps only to availability', (
    tester,
  ) async {
    await showSetup(tester);
    await tester.tap(find.widgetWithText(FilterChip, 'Upcoming'));
    await tester.pumpAndSettle();
    Slider slider() =>
        tester.widget<Slider>(find.byKey(const ValueKey('card-count')));
    slider().onChanged!(2);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recall').first);
    await tester.pumpAndSettle();
    expect(slider().value, 2);
    expect(find.text('Direction'), findsNothing);
    slider().onChanged!(4);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Upcoming'));
    await tester.pumpAndSettle();
    expect(slider().value, 3);
    await tester.tap(find.widgetWithText(FilterChip, 'Upcoming'));
    await tester.pumpAndSettle();
    expect(slider().value, 3);
  });
  testWidgets('larger counts persist and survive an empty filter', (
    tester,
  ) async {
    await showSetup(
      tester,
      studyCards: [for (var id = 1; id <= 25; id++) sample(id, 0)],
    );
    await tester.tap(find.widgetWithText(FilterChip, 'Upcoming'));
    await tester.pumpAndSettle();
    Slider slider() =>
        tester.widget<Slider>(find.byKey(const ValueKey('card-count')));
    slider().onChanged!(17);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recall').first);
    await tester.pumpAndSettle();
    expect(slider().value, 17);
    await tester.tap(find.widgetWithText(FilterChip, 'Upcoming'));
    await tester.pumpAndSettle();
    expect(find.text('No cards match these filters'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'Upcoming'));
    await tester.pumpAndSettle();
    expect(slider().value, 17);
    // Recreate the setup page with its saved preferences still in place.
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewProgressionSettingsProvider.overrideWith(
            (ref) async => const ReviewProgressionSettings(),
          ),
          cardsDashboardProvider.overrideWith(
            (ref) => Stream.value(
              CardsDashboard(
                cards: [for (var id = 1; id <= 25; id++) sample(id, 0)],
              ),
            ),
          ),
          languageDirectionProvider(
            'Chinese',
          ).overrideWith((ref) => StudyCue.fromLanguage),
        ],
        child: app,
      ),
    );
    await tester.pumpAndSettle();
    expect(slider().value, 17);
  });
  testWidgets('multi-select adds Upcoming without removing Current or Past', (
    tester,
  ) async {
    await showSetup(tester);
    await tester.tap(find.widgetWithText(FilterChip, 'Upcoming'));
    await tester.pumpAndSettle();
    expect(find.text('4 available'), findsOneWidget);
    await tester.tap(find.text('Recall').first);
    await tester.pumpAndSettle();
    expect(find.text('4 available'), findsOneWidget);
  });
}
