import 'package:nx_cards/account/account_session.dart';
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
import 'package:nx_cards/tutor/voice_tutor_page.dart';

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
    for (final direction in StudyCue.values)
      direction: CardSchedule.initial(
        enabled: direction != StudyCue.backToFront,
      ),
    for (final cue in StudyCue.languageDirections)
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
    for (final direction in StudyCue.languageDirections)
      direction: [
        for (var i = 0; i < successes; i++)
          CardReview(
            id: '$id-${direction.name}-$i',
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
  RecallComponent cue = RecallComponent.meaning,
  String language = 'Chinese',
  List<StudyCard>? studyCards,
  Set<RecallComponent>? directions,
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
        activeCardsSessionProvider.overrideWith((_) async => null),
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
  testWidgets(
    'Silent persists and due admits a paired question with a not-due answer',
    (tester) async {
      final original = sample(50, 0, due: false);
      final card = original.copyWith(
        content: (original.content as LanguageCardContent).copyWith(
          audioUrl: '/word',
        ),
        schedules: {
          ...original.schedules,
          StudyCue.meaningToSound: original
              .scheduleFor(StudyCue.meaningToSound)
              .copyWith(dueAt: DateTime.utc(2020)),
        },
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        NativeDrawingSession.channel,
        (call) async => false,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          NativeDrawingSession.channel,
          null,
        ),
      );
      final library = _ReviewLibrary();
      await showSetup(tester, studyCards: [card], library: library);
      expect(
        tester
            .widget<Switch>(find.byKey(const ValueKey('recall-silent')))
            .value,
        isFalse,
      );
      await tester.tap(find.byKey(const ValueKey('recall-silent')));
      await tester.pumpAndSettle();
      expect(
        find.text('1 card, 2 questions, 4 directions available'),
        findsOneWidget,
      );
      await tester.tap(find.text('Due'));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('study_setup.v4.recall.Chinese')!;
      await tester.tap(find.text('Start recall'));
      await tester.pumpAndSettle();
      final session = tester.widget<StudySessionPage>(
        find.byType(StudySessionPage),
      );
      expect(session.prompts, hasLength(1));
      expect(session.prompts.single.testedCues, {
        StudyCue.meaningToSound,
        StudyCue.meaningToScript,
      });
      final container = ProviderScope.containerOf(
        tester.element(find.byType(StudySessionPage)),
      );
      expect(container.read(cardAudioRepositoryProvider), isNull);
      await tester.tap(find.text('Show answer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      expect(
        library.saved!.scheduleFor(StudyCue.meaningToSound).reviewCount,
        1,
      );
      expect(
        library.saved!.scheduleFor(StudyCue.meaningToScript).reviewCount,
        1,
      );
      expect(
        library.saved!.scheduleFor(StudyCue.scriptToMeaning).reviewCount,
        0,
      );
      await tester.pumpWidget(const SizedBox());
      await showSetup(
        tester,
        studyCards: [card],
        preferences: {'study_setup.v4.recall.Chinese': saved},
      );
      expect(
        tester
            .widget<Switch>(find.byKey(const ValueKey('recall-silent')))
            .value,
        isTrue,
      );
    },
  );

  testWidgets(
    'By date range slider includes five newest groups and updates counts',
    (tester) async {
      final cards = [
        for (var day = 20; day <= 26; day++)
          sample(day, 1).copyWith(addedToCurrentAt: '2026-10-$day'),
        sample(100, 1).copyWith(addedToCurrentAt: '2026-10-26'),
        sample(101, 1),
      ];
      await showSetup(tester, studyCards: cards);
      await tester.tap(find.text('Strong'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('By date'));
      await tester.pumpAndSettle();
      RangeSlider slider() => tester.widget<RangeSlider>(
        find.byKey(const ValueKey('recall-date-range')),
      );
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(slider().max, 4);
      expect(slider().values, const RangeValues(4, 4));
      expect(
        find.text('2 cards, 4 questions, 8 directions available'),
        findsOneWidget,
      );
      slider().onChanged!(const RangeValues(3, 4));
      await tester.pumpAndSettle();
      expect(
        find.text('3 cards, 6 questions, 12 directions available'),
        findsOneWidget,
      );
      slider().onChanged!(const RangeValues(0, 4));
      await tester.pumpAndSettle();
      expect(
        find.text('6 cards, 12 questions, 24 directions available'),
        findsOneWidget,
      );
      slider().onChanged!(const RangeValues(0, 2));
      await tester.pumpAndSettle();
      expect(
        find.text('3 cards, 6 questions, 12 directions available'),
        findsOneWidget,
      );
      slider().onChanged!(const RangeValues(2, 2));
      await tester.pumpAndSettle();
      expect(
        find.text('1 card, 2 questions, 4 directions available'),
        findsOneWidget,
      );
      await tester.binding.setSurfaceSize(const Size(320, 844));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('single dated group has a fixed range and keeps its cards', (
    tester,
  ) async {
    await showSetup(
      tester,
      studyCards: [sample(1, 1).copyWith(addedToCurrentAt: '2026-10-26')],
    );
    await tester.tap(find.text('By date'));
    await tester.pumpAndSettle();
    final slider = tester.widget<RangeSlider>(
      find.byKey(const ValueKey('recall-date-range')),
    );
    expect(slider.values, const RangeValues(0, 0));
    expect(slider.onChanged, isNull);
    expect(
      find.text('1 card, 2 questions, 4 directions available'),
      findsOneWidget,
    );
  });

  testWidgets('By date excludes existing undated cards', (tester) async {
    await showSetup(tester);
    await tester.tap(find.text('By date'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No dated cards yet'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.text('No cards match these filters'), findsOneWidget);
  });

  testWidgets(
    'AI Start opens the selected ten cards with regular recall sound off',
    (tester) async {
      await showSetup(
        tester,
        studyCards: [for (var id = 1; id <= 15; id++) sample(id, 0)],
        library: _ReviewLibrary(),
        preferences: {
          'study_setup.v4.recall.Chinese':
              '{"mode":"ai","sound":false,"writing":false,"count":5,"retainedMinPercentage":0,"retainedMaxPercentage":100}',
        },
      );
      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('card-count')),
      );
      slider.onChanged!(10);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Slider>(find.byKey(const ValueKey('card-count'))).value,
        10,
      );
      await tester.tap(find.text('Start AI tutor'));
      await tester.pumpAndSettle();
      expect(find.text('No cards match these filters'), findsNothing);
      final page = tester.widget<VoiceStudySessionPage>(
        find.byType(VoiceStudySessionPage),
      );
      expect(page.prompts.map((p) => p.cardId).toSet(), hasLength(10));
      expect(page.prompts.every((p) => !p.cue.involvesScript), isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('AI recall ignores silent recall preference and preserves it', (
    tester,
  ) async {
    await showSetup(
      tester,
      studyCards: [sample(1, 0)],
      preferences: {
        'study_setup.v4.recall.Chinese':
            '{"mode":"ai","sound":false,"writing":false,"retainedMinPercentage":0,"retainedMaxPercentage":100}',
      },
    );
    expect(find.text('No cards match these filters'), findsNothing);
    expect(
      find.textContaining(
        RegExp(r'^1 card(?:, \d+ questions?, \d+ directions?)? available$'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Start AI tutor'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Recall').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('recall-sound')), findsNothing);
    expect(find.byKey(const ValueKey('recall-directions-all')), findsOneWidget);
    await tester.tap(find.text('AI').first);
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        RegExp(r'^1 card(?:, \d+ questions?, \d+ directions?)? available$'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('mixed spoken-only and written cards keep native recall', (
    tester,
  ) async {
    final written = sample(1, 0);
    final spoken = sample(2, 0).copyWith(
      content: (sample(2, 0).content as LanguageCardContent).copyWith(
        spokenOnly: true,
      ),
    );
    Map<dynamic, dynamic>? opened;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      NativeDrawingSession.channel,
      (call) async {
        if (call.method == 'available') return true;
        if (call.method == 'open') {
          opened = call.arguments as Map;
          return null;
        }
        return null;
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
      studyCards: [written, spoken],
      directions: RecallComponent.values.toSet(),
      library: _ReviewLibrary(),
    );
    await tester.tap(find.text('Start recall'));
    await tester.pumpAndSettle();
    expect(opened, isNotNull);
    expect(opened!['recall'], true);
    expect((opened!['cards'] as List).length, greaterThan(1));
    expect(find.byType(StudySessionPage), findsNothing);
  });

  testWidgets(
    'starting a direction-count round hydrates cards and grades only the tested direction',
    (tester) async {
      final original = sample(40, 0);
      final full = original.copyWith(
        content: (original.content as LanguageCardContent).copyWith(
          audioUrl: '/word.mp3',
        ),
      );
      final store = _ReviewStore(full);
      final library = _ReviewLibrary();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        NativeDrawingSession.channel,
        (call) async => false,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          NativeDrawingSession.channel,
          null,
        ),
      );
      await showSetup(
        tester,
        studyCards: [full.copyWith(isSummary: true)],
        directions: RecallComponent.values.toSet(),
        store: store,
        library: library,
      );
      expect(
        find.textContaining(
          RegExp(r'^1 card(?:, \d+ questions?, \d+ directions?)? available$'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Start recall'));
      await tester.pumpAndSettle();
      final session = tester.widget<StudySessionPage>(
        find.byType(StudySessionPage),
      );
      expect(session.prompts, hasLength(3));
      expect(
        session.prompts.map((p) => (p.cardId, p.cue.source)).toSet(),
        hasLength(3),
      );
      expect(
        session.prompts.every(
          (p) => p.testedCues.length == 2 && !p.card.isSummary,
        ),
        isTrue,
      );
      final tested = session.prompts.first.testedCues;
      await tester.tap(find.text('Show answer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();
      final saved = library.saved!;
      for (final cue in StudyCue.languageDirections) {
        expect(
          saved.reviewHistoryFor(cue).length,
          tested.contains(cue) ? 1 : 0,
        );
        if (tested.contains(cue)) {
          expect(saved.reviewHistoryFor(cue).single.rating, 1);
        }
      }
    },
  );

  testWidgets(
    'Exact directions update By date counts and persist at narrow widths',
    (tester) async {
      final card = sample(1, 0).copyWith(
        addedToCurrentAt: '2026-10-26',
        content: const LanguageCardContent(
          english: 'cat',
          originalScript: '猫',
          transliteration: 'mao',
          audioUrl: '/cat',
        ),
      );
      await showSetup(tester, studyCards: [card]);
      await tester.tap(find.text('By date'));
      await tester.pumpAndSettle();
      expect(
        find.text('1 card, 3 questions, 6 directions available'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('recall-directions-clear')));
      await tester.pumpAndSettle();
      expect(find.text('No cards match these filters'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('recall-source-script')));
      await tester.pumpAndSettle();
      expect(
        find.text('1 card, 1 question, 2 directions available'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('recall-source-meaning')));
      await tester.pumpAndSettle();
      expect(
        find.text('1 card, 2 questions, 4 directions available'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('recall-writing')), findsNothing);
      expect(
        tester.getCenter(find.text('Recall directions')).dy,
        tester
            .getCenter(find.byKey(const ValueKey('recall-directions-all')))
            .dy,
      );
      await tester.tap(find.text('Retention'));
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.text('Retention')).dy,
        tester.getCenter(find.widgetWithText(TextButton, 'Weak')).dy,
      );
      await tester.tap(find.text('By date'));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('recall-writing')));
      await tester.tap(find.byKey(const ValueKey('recall-writing')));
      await tester.pumpAndSettle();
      expect(
        find.text('1 card, 2 questions, 3 directions available'),
        findsOneWidget,
      );
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('study_setup.v4.recall.Chinese')!;
      await tester.pumpWidget(const SizedBox());
      await showSetup(
        tester,
        studyCards: [card],
        preferences: {'study_setup.v4.recall.Chinese': saved},
      );
      expect(
        find.text('1 card, 2 questions, 3 directions available'),
        findsOneWidget,
      );
      await tester.binding.setSurfaceSize(const Size(320, 844));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('recall-directions-all')),
      );
      await tester.tap(find.byKey(const ValueKey('recall-directions-all')));
      await tester.pumpAndSettle();
      expect(
        find.text('1 card, 3 questions, 4 directions available'),
        findsOneWidget,
      );
    },
  );

  for (final cue in [RecallComponent.sound, RecallComponent.meaning]) {
    testWidgets(
      'unavailable native renderer hydrates spoken-only $cue before grading No',
      (tester) async {
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
            return false;
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
        expect(session.prompts.every((p) => p.card.isSummary), false);
        expect(session.prompts, hasLength(2));
        expect({
          StudyCue.meaningToSound,
          StudyCue.soundToMeaning,
        }, contains(session.prompts.first.cue));
        await tester.tap(find.text('Show answer'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('No'));
        await tester.pumpAndSettle();
        expect(library.saved, isNotNull);
        expect(library.saved!.isSummary, false);
        expect(
          library.saved!
              .reviewHistoryFor(
                library.saved!.reviewHistory.keys.firstWhere(
                  (c) => library.saved!
                      .reviewHistoryFor(c)
                      .any((r) => r.rating == 1),
                ),
              )
              .last
              .rating,
          1,
        );
        expect(
          library.saved!.reviewHistoryFor(StudyCue.meaningToScript).length,
          3,
        );
        expect(find.textContaining('Could not save review'), findsNothing);
      },
    );
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
      (_) async => false,
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
    expect(
      find.textContaining('Could not refresh recall queue'),
      findsOneWidget,
    );
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
        directions: {RecallComponent.meaning},
        studyCards: [sample(1, 0), sample(2, 10), sample(3, 0, due: false)],
      );
      expect(
        find.textContaining(
          RegExp(r'^3 cards(?:, \d+ questions?, \d+ directions?)? available$'),
        ),
        findsOneWidget,
      );
      final retention = tester.widget<RangeSlider>(
        find.byKey(const ValueKey('recall-retention')),
      );
      retention.onChanged!(const RangeValues(0, 0));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          RegExp(r'^2 cards(?:, \d+ questions?, \d+ directions?)? available$'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Due'));
      await tester.pumpAndSettle();
      expect(find.text('2 cards due'), findsOneWidget);
      expect(find.byType(Slider), findsNWidgets(2));
      expect(
        tester.widget<Slider>(find.byKey(const ValueKey('card-count'))).max,
        4,
      );
      tester
          .widget<Slider>(find.byKey(const ValueKey('due-retention')))
          .onChanged!(80);
      await tester.pumpAndSettle();
      expect(find.text('80–100%'), findsOneWidget);
      expect(find.text('1 card due'), findsOneWidget);
      await tester.tap(find.text('Retention'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          RegExp(r'^2 cards(?:, \d+ questions?, \d+ directions?)? available$'),
        ),
        findsOneWidget,
      );
      expect(find.byType(RangeSlider), findsOneWidget);
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
          'study_setup.v4.recall.Tamil':
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
        directions: RecallComponent.values.toSet(),
        preferences: {
          'study_setup.v4.recall.Tamil': '{"retainedMaxPercentage":0}',
        },
      );
      expect(find.text('Similar'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Recall format')).dy,
        lessThan(tester.getTopLeft(find.text('Recall directions')).dy),
      );
      await tester.tap(find.text('Similar'));
      await tester.pumpAndSettle();
      expect(find.text('Retention'), findsNothing);
      expect(find.byKey(const ValueKey('group-similar-sounds')), findsNothing);
      expect(find.text('How many recall groups?'), findsOneWidget);
      expect(find.text('3 recall groups available'), findsOneWidget);
      expect(find.byKey(const ValueKey('direction-sound')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('direction-script')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilterChip>(find.byKey(const ValueKey('direction-meaning')))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<FilterChip>(find.byKey(const ValueKey('direction-script')))
            .selected,
        isTrue,
      );
      expect(find.text('3 recall groups available'), findsOneWidget);
      await tester.tap(find.text('Sound').first);
      await tester.pumpAndSettle();
      expect(find.byType(DirectionChoices), findsNothing);
      expect(find.text('Retention'), findsNothing);
      expect(find.text('1 recall groups available'), findsOneWidget);
      await tester.tap(find.text('Standard'));
      await tester.pumpAndSettle();
      expect(find.text('Retention'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('recall-directions-all')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await showSetup(tester);
      expect(find.text('Similar'), findsNothing);
    },
  );

  testWidgets('Recall for unions overlap without double-counting questions', (
    tester,
  ) async {
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
      directions: RecallComponent.values.toSet(),
    );
    expect(
      find.textContaining(
        RegExp(r'^27 cards(?:, \d+ questions?, \d+ directions?)? available$'),
      ),
      findsOneWidget,
    );
    expect(find.text('Write'), findsNothing);
    final titles = [
      'Recall format',
      'Recall directions',
      'Retention',
      'How many questions?',
    ];
    final positions = titles
        .map((title) => tester.getTopLeft(find.text(title)).dy)
        .toList();
    expect(positions, orderedEquals([...positions]..sort()));
    await tester.tap(find.text('AI').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('direction-script')), findsNothing);
    expect(
      find.textContaining(
        RegExp(r'^27 cards(?:, \d+ questions?, \d+ directions?)? available$'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Recall').first);
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        RegExp(r'^27 cards(?:, \d+ questions?, \d+ directions?)? available$'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('recall-source-meaning')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        RegExp(r'^27 cards(?:, \d+ questions?, \d+ directions?)? available$'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('recall-source-meaning')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        RegExp(r'^27 cards(?:, \d+ questions?, \d+ directions?)? available$'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('saved Write format migrates to Standard for reverse recall', (
    tester,
  ) async {
    await showSetup(
      tester,
      cue: RecallComponent.script,
      preferences: {
        'study_setup.v4.recall.Chinese': '{"recallPresentation":"write"}',
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
      await showSetup(tester, cue: RecallComponent.sound);
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
    expect(
      find.textContaining(
        RegExp(r'^3 cards(?:, \d+ questions?, \d+ directions?)? available$'),
      ),
      findsOneWidget,
    );
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
      expect(
        find.textContaining(
          RegExp(r'^5 cards(?:, \d+ questions?, \d+ directions?)? available$'),
        ),
        findsOneWidget,
      );
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
  testWidgets(
    'New selects only untouched cards and counts individual directions',
    (tester) async {
      final fresh = sample(100, 0).copyWith(
        schedules: {
          for (final cue in StudyCue.languageDirections)
            cue: CardSchedule.initial(enabled: true),
        },
      );
      await showSetup(tester, studyCards: [fresh, sample(101, 1)]);
      await tester.tap(find.widgetWithText(TextButton, 'New'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          RegExp(r'^1 card(?:, \d+ questions?, \d+ directions?)? available$'),
        ),
        findsOneWidget,
      );
      expect(
        find.text('1 card, 2 questions, 4 directions available'),
        findsOneWidget,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().any(
          (key) => prefs.get(key).toString().contains('"newOnly":true'),
        ),
        isTrue,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Weak'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          RegExp(r'^2 cards(?:, \d+ questions?, \d+ directions?)? available$'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('retention shortcuts replace due and stage filters', (
    tester,
  ) async {
    await showSetup(tester);
    expect(find.textContaining('Strong cards due'), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, 'Strong'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        RegExp(r'^2 cards(?:, \d+ questions?, \d+ directions?)? available$'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Weak'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        RegExp(r'^1 card(?:, \d+ questions?, \d+ directions?)? available$'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('AI').first);
    await tester.pumpAndSettle();
    expect(find.text('Start AI tutor'), findsOneWidget);
  });
  testWidgets('untried reverse direction of Active cards is Current', (
    tester,
  ) async {
    await showSetup(tester, cue: RecallComponent.script);
    expect(
      find.textContaining(
        RegExp(r'^3 cards(?:, \d+ questions?, \d+ directions?)? available$'),
      ),
      findsOneWidget,
    );
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
          ).overrideWith((ref) => {RecallComponent.meaning}),
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
