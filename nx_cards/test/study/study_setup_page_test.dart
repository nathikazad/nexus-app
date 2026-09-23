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
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(const Size(900, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final cards = [
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
  testWidgets('study has four active cards; recall omits only not-due Past', (
    tester,
  ) async {
    await showSetup(tester);
    expect(find.text('4 available'), findsOneWidget);
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
    'direction comes from language page; no third cue or local selector',
    (tester) async {
      await showSetup(tester, cue: StudyCue.toLanguage);
      await tester.tap(find.text('Recall').first);
      await tester.pumpAndSettle();
      expect(
        find.text('4 available'),
        findsOneWidget,
      ); // all four are untried in reverse
      expect(find.textContaining('Chinese → English'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Transliteration'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'Chinese'), findsNothing);
    },
  );
  testWidgets(
    'multi-select excludes Upcoming without removing Current or Past',
    (tester) async {
      await showSetup(tester);
      await tester.tap(find.widgetWithText(FilterChip, 'Upcoming'));
      await tester.pumpAndSettle();
      expect(find.text('3 available'), findsOneWidget);
      await tester.tap(find.text('Recall').first);
      await tester.pumpAndSettle();
      expect(find.text('2 available'), findsOneWidget);
    },
  );
}
