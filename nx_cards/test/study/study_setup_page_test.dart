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
  bool prep = false,
}) => StudyCard(
  id: id,
  content: LanguageCardContent(
    english: 'word $id',
    originalScript: '字$id',
    transliteration: 'zi',
  ),
  suspended: false,
  learningStatus: prep
      ? LearningStatus.practice
      : active
      ? LearningStatus.recall
      : LearningStatus.future,
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
  Set<StudyCue>? directions,
  StudySetupFlow flow = StudySetupFlow.recall,
  Map<String, Object> preferences = const {},
}) async {
  SharedPreferences.setMockInitialValues(preferences);
  await tester.binding.setSurfaceSize(const Size(900, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final cards =
      studyCards ??
      [
        sample(1, 0, prep: true),
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
        selectedDirectionsProvider(
          'Chinese',
        ).overrideWith((ref) => directions ?? {cue}),
      ],
      child: MaterialApp(
        home: StudySetupPage(
          title: 'Chinese',
          flow: flow,
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
  testWidgets(
    'all three directions offer 81 items and changing selection updates the count',
    (tester) async {
      final cards = [
        for (var id = 1; id <= 27; id++)
          sample(id, 0).copyWith(
            content: LanguageCardContent(
              english: 'word $id',
              originalScript: '字',
              transliteration: 'zi',
              audioUrl: '/audio/$id.mp3',
            ),
          ),
      ];
      await showSetup(
        tester,
        studyCards: cards,
        directions: StudyCue.activeDirections.toSet(),
      );
      expect(find.text('81 recall items available'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('direction-from_audio')));
      await tester.pumpAndSettle();
      expect(find.text('54 recall items available'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('direction-to_language')));
      await tester.pumpAndSettle();
      expect(find.text('27 recall items available'), findsOneWidget);
    },
  );

  testWidgets('a saved Write format becomes Standard for reverse recall', (
    tester,
  ) async {
    await showSetup(
      tester,
      cue: StudyCue.toLanguage,
      preferences: {
        'study_setup.v3.recall.Chinese': '{"recallPresentation":"write"}',
      },
    );
    final formats = tester.widget<SegmentedButton<RecallPresentation>>(
      find.byType(SegmentedButton<RecallPresentation>),
    );
    expect(formats.selected, {RecallPresentation.standard});
    expect(formats.segments.map((s) => s.value), [
      RecallPresentation.standard,
      RecallPresentation.fast,
    ]);
  });

  testWidgets(
    'audio direction offers the existing three formats without a prompt toggle',
    (tester) async {
      await showSetup(tester, cue: StudyCue.fromAudio);
      expect(find.text('Read'), findsNothing);
      expect(find.text('Listen'), findsNothing);
      expect(find.text('Recall format'), findsOneWidget);
      expect(find.text('Write'), findsOneWidget);
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('Fast'), findsOneWidget);
      await tester.tap(find.text('Write'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SegmentedButton<RecallPresentation>>(
              find.byType(SegmentedButton<RecallPresentation>),
            )
            .selected,
        {RecallPresentation.write},
      );
    },
  );

  testWidgets('Recall offers Current and Past including not-due Past', (
    tester,
  ) async {
    await showSetup(tester);
    expect(find.text('3 recall items available'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Practice'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Weak'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Strong'), findsOneWidget);
    expect(find.text('Recall format'), findsOneWidget);
    expect(find.text('Write'), findsOneWidget);
    expect(find.text('Start recall'), findsOneWidget);
    expect(find.text('Practice'), findsNothing);
  });
  testWidgets('Practice only offers format and count, and only Prep cards', (
    tester,
  ) async {
    await showSetup(tester, flow: StudySetupFlow.practice);
    expect(find.text('Study format'), findsOneWidget);
    expect(find.text('Study sheet'), findsOneWidget);
    expect(find.text('Draw'), findsOneWidget);
    expect(find.text('1 cards available'), findsOneWidget);
    expect(find.text('Which cards'), findsNothing);
    expect(find.text('Recall score'), findsNothing);
    expect(find.textContaining('Strong cards due'), findsNothing);
    expect(find.byType(FilterChip), findsNothing);
    expect(find.text('AI'), findsNothing);
  });
  testWidgets('retention shortcuts replace due and stage filters', (
    tester,
  ) async {
    await showSetup(tester);
    expect(find.textContaining('Strong cards due'), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, 'Strong'));
    await tester.pumpAndSettle();
    expect(find.text('2 recall items available'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Weak'));
    await tester.pumpAndSettle();
    expect(find.text('1 recall items available'), findsOneWidget);
    await tester.tap(find.text('AI').first);
    await tester.pumpAndSettle();
    expect(find.text('Start AI tutor'), findsOneWidget);
  });
  testWidgets('untried reverse direction of Active cards is Current', (
    tester,
  ) async {
    await showSetup(tester, cue: StudyCue.toLanguage);
    expect(find.text('3 recall items available'), findsOneWidget);
    expect(find.textContaining('Chinese → English'), findsNothing);
    expect(find.widgetWithText(ChoiceChip, 'Transliteration'), findsNothing);
  });
  testWidgets(
    'count persists across Recall and AI, clamps to nearest available',
    (tester) async {
      await showSetup(tester);
      Slider slider() =>
          tester.widget<Slider>(find.byKey(const ValueKey('card-count')));
      slider().onChanged!(2);
      await tester.pumpAndSettle();
      await tester.tap(find.text('AI').first);
      await tester.pumpAndSettle();
      expect(slider().value, 2);
      await tester.tap(find.widgetWithText(TextButton, 'Weak'));
      await tester.pumpAndSettle();
      expect(slider().value, 1);
      await tester.tap(find.widgetWithText(TextButton, 'Weak'));
      await tester.pumpAndSettle();
      expect(slider().value, 1);
    },
  );
  testWidgets('larger count survives an empty selection and reopening', (
    tester,
  ) async {
    await showSetup(
      tester,
      studyCards: [for (var id = 1; id <= 25; id++) sample(id, 0)],
    );
    Slider slider() =>
        tester.widget<Slider>(find.byKey(const ValueKey('card-count')));
    slider().onChanged!(17);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Strong'));
    await tester.pumpAndSettle();
    expect(find.text('No cards match these filters'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Weak'));
    await tester.pumpAndSettle();
    expect(slider().value, 17);
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
          selectedDirectionsProvider(
            'Chinese',
          ).overrideWith((ref) => {StudyCue.fromLanguage}),
        ],
        child: app,
      ),
    );
    await tester.pumpAndSettle();
    expect(slider().value, 17);
  });
}
