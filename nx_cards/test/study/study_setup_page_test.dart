import 'package:nx_cards/audio/audio_providers.dart';
import 'package:nx_cards/study/language/drawing/native_drawing_session.dart';
import 'package:nx_cards/study/session/study_session_page.dart';
import 'package:nx_cards/sync/native/local_cards_store.dart';
import 'package:nx_cards/sync/sync_providers.dart';
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
  String language = 'Chinese',
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
  tags: {
    'Language': [language],
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
  String language = 'Chinese',
  List<StudyCard>? studyCards,
  Set<StudyCue>? directions,
  StudySetupFlow flow = StudySetupFlow.recall,
  Map<String, Object> preferences = const {},
  LocalCardsStore? store,
  CardLibrary? library,
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
        if (store != null) localCardsStoreProvider.overrideWithValue(store),
        if (library != null) cardLibraryProvider.overrideWithValue(library),
        cardAudioRepositoryProvider.overrideWithValue(null),
        cardsInvalidationProvider.overrideWithValue(() {}),
        cardsDashboardProvider.overrideWith(
          (ref) => Stream.value(CardsDashboard(cards: cards)),
        ),
        reviewProgressionSettingsProvider.overrideWith(
          (ref) async => const ReviewProgressionSettings(),
        ),
        selectedDirectionsProvider(
          language,
        ).overrideWith((ref) => directions ?? {cue}),
      ],
      child: MaterialApp(
        home: StudySetupPage(
          title: language,
          flow: flow,
          studyScope: StudyScope(language: language),
          prompts: [],
          studyCards: cards,
          fromLanguage: 'English',
          toLanguage: language,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final cue in [StudyCue.fromAudio, StudyCue.fromLanguage]) {
    testWidgets('native fallback hydrates spoken-only $cue before grading No', (
      tester,
    ) async {
      final original = sample(40, 3);
      final full = original.copyWith(
        content: (original.content as LanguageCardContent).copyWith(
          spokenOnly: true,
          audioUrl: '/word.mp3',
        ),
      );
      final summary = full.copyWith(isSummary: true, reviewHistory: const {});
      final store = _ReviewStore(full);
      final library = _ReviewLibrary();
      var availableCalls = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        NativeDrawingSession.channel,
        (call) async {
          expect(call.method, 'available');
          availableCalls++;
          return true;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          NativeDrawingSession.channel,
          null,
        ),
      );
      await showSetup(
        tester,
        studyCards: [summary],
        cue: cue,
        store: store,
        library: library,
      );
      await tester.tap(find.text('Start recall'));
      await tester.pumpAndSettle();
      expect(availableCalls, greaterThan(0));
      expect(store.loads, 1);
      final session = tester.widget<StudySessionPage>(
        find.byType(StudySessionPage),
      );
      expect(session.prompts.single.card.isSummary, false);
      expect(session.prompts.single.cue, cue);
      await tester.tap(find.text('Show answer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();
      expect(library.saved, isNotNull);
      expect(library.saved!.isSummary, false);
      expect(library.saved!.reviewHistoryFor(cue).last.rating, 1);
      expect(
        library.saved!.reviewHistoryFor(StudyCue.fromLanguage).length,
        cue == StudyCue.fromLanguage ? 4 : 3,
      );
      expect(find.textContaining('Could not save review'), findsNothing);
    });
  }

  testWidgets('failed fallback hydration keeps setup available for retry', (
    tester,
  ) async {
    final original = sample(40, 0);
    final summary = original.copyWith(
      isSummary: true,
      content: (original.content as LanguageCardContent).copyWith(
        spokenOnly: true,
      ),
    );
    final store = _ReviewStore(null);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      NativeDrawingSession.channel,
      (_) async => true,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        NativeDrawingSession.channel,
        null,
      ),
    );
    await showSetup(tester, studyCards: [summary], store: store);
    await tester.tap(find.text('Start recall'));
    await tester.pumpAndSettle();
    expect(find.byType(StudySessionPage), findsNothing);
    expect(find.textContaining('Could not start recall'), findsOneWidget);
    store.card = summary.copyWith(isSummary: false);
    await tester.tap(find.text('Start recall'));
    await tester.pumpAndSettle();
    expect(find.byType(StudySessionPage), findsOneWidget);
  });

  testWidgets(
    'Due filters by its own minimum retention and preserves Retention settings',
    (tester) async {
      await showSetup(
        tester,
        directions: {StudyCue.fromLanguage},
        studyCards: [sample(1, 0), sample(2, 10), sample(3, 0, due: false)],
      );
      expect(find.text('3 recall items available'), findsOneWidget);
      final retention = tester.widgetList<Slider>(find.byType(Slider)).first;
      retention.onChanged!(0);
      await tester.pumpAndSettle();
      expect(find.text('2 recall items available'), findsOneWidget);
      await tester.tap(find.text('Due'));
      await tester.pumpAndSettle();
      expect(find.text('2 cards due'), findsOneWidget);
      expect(find.byType(Slider), findsNWidgets(2));
      expect(
        tester.widget<Slider>(find.byKey(const ValueKey('card-count'))).max,
        2,
      );
      tester
          .widget<Slider>(find.byKey(const ValueKey('due-retention')))
          .onChanged!(80);
      await tester.pumpAndSettle();
      expect(find.text('80–100%'), findsOneWidget);
      expect(find.text('1 cards due'), findsOneWidget);
      await tester.tap(find.text('Retention'));
      await tester.pumpAndSettle();
      expect(find.text('2 recall items available'), findsOneWidget);
      expect(find.byType(Slider), findsNWidgets(2));
    },
  );

  testWidgets(
    'sound-only groups show only Sound and restore Similar without text directions',
    (tester) async {
      final cards = [
        sample(1, 0, language: 'Tamil').copyWith(
          content: const LanguageCardContent(
            english: 'word',
            originalScript: 'word',
            transliteration: 'word',
            audioUrl: '/audio',
            similarWordGroups: ['pair-sound'],
          ),
        ),
      ];
      await showSetup(
        tester,
        language: 'Tamil',
        studyCards: cards,
        preferences: {
          'study_setup.v3.recall.Tamil':
              '{"recallPresentation":"similar","similarType":"written","groupCount":3}',
        },
      );
      expect(find.text('Sound'), findsOneWidget);
      expect(find.text('Written'), findsNothing);
      expect(find.byType(DirectionChoices), findsNothing);
      expect(find.text('Retention'), findsNothing);
      expect(find.text('1 recall groups available'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Similar is dynamic, uses full group count, and hides retention and sound directions',
    (tester) async {
      final cards = [
        for (var id = 1; id <= 3; id++)
          sample(id, 0, language: 'Tamil').copyWith(
            content: LanguageCardContent(
              english: 'word $id',
              originalScript: 'word$id',
              transliteration: 'word',
              audioUrl: '/audio/$id',
              similarWordGroups: ['all-sound', if (id < 3) 'pair-write'],
            ),
          ),
      ];
      await showSetup(
        tester,
        language: 'Tamil',
        studyCards: cards,
        directions: StudyCue.activeDirections.toSet(),
        preferences: {
          'study_setup.v3.recall.Tamil': '{"retainedMaxPercentage":0}',
        },
      );
      expect(find.text('Similar'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Recall format')).dy,
        lessThan(tester.getTopLeft(find.text('What to show on the front?')).dy),
      );
      await tester.tap(find.text('Similar'));
      await tester.pumpAndSettle();
      expect(find.text('Retention'), findsNothing);
      expect(find.byKey(const ValueKey('group-similar-sounds')), findsNothing);
      expect(find.text('How many recall groups?'), findsOneWidget);
      expect(find.text('1 recall groups available'), findsOneWidget);
      expect(find.byKey(const ValueKey('direction-from_audio')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('direction-to_language')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilterChip>(
              find.byKey(const ValueKey('direction-from_language')),
            )
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<FilterChip>(
              find.byKey(const ValueKey('direction-to_language')),
            )
            .selected,
        isTrue,
      );
      expect(find.text('2 recall groups available'), findsOneWidget);
      await tester.tap(find.text('Sound'));
      await tester.pumpAndSettle();
      expect(find.byType(DirectionChoices), findsNothing);
      expect(find.text('Retention'), findsNothing);
      expect(find.text('1 recall groups available'), findsOneWidget);
      await tester.tap(find.text('Standard'));
      await tester.pumpAndSettle();
      expect(find.text('Retention'), findsOneWidget);
      expect(find.byType(DirectionChoices), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await showSetup(tester);
      expect(find.text('Similar'), findsNothing);
    },
  );

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
      expect(find.text('Write'), findsNothing);
      final titles = [
        'Recall format',
        'What to show on the front?',
        'Retention',
        'How many recall items?',
      ];
      final positions = titles
          .map((title) => tester.getTopLeft(find.text(title)).dy)
          .toList();
      expect(positions, orderedEquals([...positions]..sort()));
      await tester.tap(find.text('AI').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('direction-to_language')), findsNothing);
      expect(find.text('54 recall items available'), findsOneWidget);
      await tester.tap(find.text('Recall').first);
      await tester.pumpAndSettle();
      expect(find.text('81 recall items available'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('direction-from_audio')));
      await tester.pumpAndSettle();
      expect(find.text('54 recall items available'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('direction-to_language')));
      await tester.pumpAndSettle();
      expect(find.text('27 recall items available'), findsOneWidget);
    },
  );

  testWidgets('saved Write format migrates to Standard for reverse recall', (
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
    'audio direction offers the two formats without a prompt toggle',
    (tester) async {
      await showSetup(tester, cue: StudyCue.fromAudio);
      expect(find.text('Read'), findsNothing);
      expect(find.text('Listen'), findsNothing);
      expect(find.text('Recall format'), findsOneWidget);
      expect(find.text('Write'), findsNothing);
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('Fast'), findsOneWidget);
      await tester.tap(find.text('Standard'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SegmentedButton<RecallPresentation>>(
              find.byType(SegmentedButton<RecallPresentation>),
            )
            .selected,
        {RecallPresentation.standard},
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
    expect(find.text('Write'), findsNothing);
    expect(find.text('Start recall'), findsOneWidget);
    expect(find.text('Practice'), findsNothing);
  });
  testWidgets(
    'Practice offers directions, format, and count for the selected cards',
    (tester) async {
      await showSetup(tester, flow: StudySetupFlow.practice);
      expect(find.text('Study format'), findsOneWidget);
      expect(find.text('Study sheet'), findsOneWidget);
      expect(find.text('Draw'), findsOneWidget);
      expect(find.text('5 cards available'), findsOneWidget);
      expect(find.text('Which cards?'), findsOneWidget);
      expect(find.text('Recall score'), findsNothing);
      expect(find.textContaining('Strong cards due'), findsNothing);
      expect(find.byType(FilterChip), findsNWidgets(3));
      final sections = ['Which cards?', 'Study format', 'How many cards?'];
      final positions = sections
          .map((title) => tester.getTopLeft(find.text(title)).dy)
          .toList();
      expect(positions, orderedEquals([...positions]..sort()));
      expect(find.text('AI'), findsNothing);
    },
  );
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

class _ReviewStore implements LocalCardsStore {
  _ReviewStore(this.card);
  StudyCard? card;
  int loads = 0;
  @override
  Future<StudyCard?> getCard(int id) async {
    loads++;
    return card;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ReviewLibrary implements CardLibrary {
  StudyCard? saved;
  @override
  Future<void> saveSchedule(StudyCard card) async {
    if (card.isSummary) {
      throw StateError('Load the full card before reviewing.');
    }
    saved = card;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
