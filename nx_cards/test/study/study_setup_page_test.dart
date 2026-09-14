import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/audio/audio_providers.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/study/study_setup_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('configures a transliteration-cue session', (tester) async {
    final card = StudyCard(
      id: 1,
      content: const LanguageCardContent(
        english: 'talent',
        originalScript: 'കഴിവ്',
        transliteration: 'kazhivu',
      ),
      schedules: const <StudyCue, CardSchedule>{
        StudyCue.fromLanguage: CardSchedule.initial(enabled: true),
        StudyCue.toLanguage: CardSchedule.initial(enabled: true),
        StudyCue.transliteration: CardSchedule.initial(enabled: true),
      },
      reviewHistory: const <StudyCue, List<CardReview>>{
        StudyCue.fromLanguage: <CardReview>[],
        StudyCue.toLanguage: <CardReview>[],
        StudyCue.transliteration: <CardReview>[],
      },
      suspended: false,
      learningStatus: LearningStatus.learning,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardsDashboardProvider.overrideWith(
            (_) => Stream.value(CardsDashboard(cards: [card])),
          ),
        ],
        child: MaterialApp(
          home: StudySetupPage(
            title: 'Malayalam',
            prompts: card.prompts.toList(),
            studyCards: [card],
            fromLanguage: 'English',
            toLanguage: 'Malayalam',
          ),
        ),
      ),
    );

    expect(find.text('How do you want to study?'), findsOneWidget);
    await tester.tap(find.text('Recall'));
    await tester.pumpAndSettle();
    expect(find.text('Recall format'), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('Fast'), findsOneWidget);
    expect(find.text('Choose the order'), findsNothing);
    expect(find.widgetWithText(FilterChip, 'All'), findsOneWidget);
    expect(find.text('Due'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('What should be in front?')).dy,
      lessThan(tester.getTopLeft(find.text('Which cards?')).dy),
    );
    final english = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'English'),
    );
    final learning = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Current'),
    );
    final learnt = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Past'),
    );
    expect(english.selected, isTrue);
    expect(learning.selected, isTrue);
    expect(learnt.selected, isFalse);
    expect(find.text('What should be in back?'), findsNothing);
    await tester.ensureVisible(find.text('Transliteration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transliteration'));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start recall'));
    await tester.pumpAndSettle();

    expect(find.text('kazhivu'), findsOneWidget);
  });

  testWidgets('offers an AI voice mode for the selected source', (
    tester,
  ) async {
    final card = StudyCard(
      id: 1,
      content: const LanguageCardContent(
        english: 'talent',
        originalScript: 'കഴിവ്',
        transliteration: 'kazhivu',
      ),
      schedules: const <StudyCue, CardSchedule>{
        StudyCue.fromLanguage: CardSchedule.initial(enabled: true),
      },
      reviewHistory: const <StudyCue, List<CardReview>>{
        StudyCue.fromLanguage: <CardReview>[],
      },
      suspended: false,
      learningStatus: LearningStatus.learning,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardsDashboardProvider.overrideWith(
            (_) => Stream.value(CardsDashboard(cards: [card])),
          ),
        ],
        child: MaterialApp(
          home: StudySetupPage(
            title: 'Malayalam',
            prompts: card.prompts.toList(),
            studyCards: [card],
            fromLanguage: 'English',
            toLanguage: 'Malayalam',
          ),
        ),
      ),
    );

    await tester.tap(find.text('AI'));
    await tester.pumpAndSettle();

    expect(find.text('What should be in front?'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Current'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Past'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Retained'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'All'), findsOneWidget);
    expect(find.text('Due'), findsOneWidget);
    expect(find.text('How many cards?'), findsOneWidget);
    expect(find.text('Choose the order'), findsNothing);
    await tester.ensureVisible(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pump();
    expect(find.text('Start AI tutor'), findsOneWidget);
  });

  testWidgets('study mode reuses word filters and card count from recall', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    final cards = <StudyCard>[
      _recallFilterCard(
        id: 1,
        learningStatus: LearningStatus.learning,
        state: 'learning',
        lastReviewedAt: now,
      ),
      _recallFilterCard(
        id: 2,
        learningStatus: LearningStatus.learning,
        state: 'relearning',
        lastReviewedAt: now,
      ),
      _recallFilterCard(
        id: 3,
        learningStatus: LearningStatus.learnt,
        state: 'review',
        lastReviewedAt: now,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardsDashboardProvider.overrideWith(
            (_) => Stream.value(CardsDashboard(cards: cards)),
          ),
        ],
        child: MaterialApp(
          home: StudySetupPage(
            title: 'Malayalam',
            prompts: [for (final card in cards) ...card.prompts],
            studyCards: cards,
            fromLanguage: 'English',
            toLanguage: 'Malayalam',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Which cards?'), findsOneWidget);
    expect(find.text('How many cards?'), findsOneWidget);
    expect(find.text('All words on one page'), findsNothing);
    expect(find.text('Choose the order'), findsNothing);
    expect(find.text('2 available'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Which cards?')).dy,
      lessThan(tester.getTopLeft(find.text('How many cards?')).dy),
    );

    final setupCards = tester.widgetList<Card>(find.byType(Card)).toList();
    expect(setupCards, hasLength(3));
    expect(
      find.descendant(
        of: find.byWidget(setupCards[0]),
        matching: find.text('01'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byWidget(setupCards[1]),
        matching: find.text('02'),
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(find.widgetWithText(FilterChip, 'Past'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Past'));
    await tester.pump();
    expect(find.text('3 available'), findsOneWidget);

    final countSlider = tester.widget<Slider>(find.byType(Slider).last);
    countSlider.onChanged!(2);
    await tester.pump();
    await tester.ensureVisible(find.text('Open study sheet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open study sheet'));
    await tester.pumpAndSettle();

    expect(find.text('2 words'), findsOneWidget);
    expect(find.text('word 1'), findsOneWidget);
    expect(find.text('word 2'), findsOneWidget);
    expect(find.text('word 3'), findsNothing);
  });

  testWidgets('recall filters current and past cards by memory state', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    final cards = <StudyCard>[
      _recallFilterCard(
        id: 1,
        learningStatus: LearningStatus.learning,
        state: 'learning',
        lastReviewedAt: now,
        due: true,
      ),
      _recallFilterCard(
        id: 2,
        learningStatus: LearningStatus.learning,
        state: 'relearning',
        lastReviewedAt: now,
      ),
      _recallFilterCard(
        id: 3,
        learningStatus: LearningStatus.learnt,
        state: 'review',
        lastReviewedAt: now,
        due: true,
      ),
      _recallFilterCard(
        id: 4,
        learningStatus: LearningStatus.learnt,
        state: 'learning',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardsDashboardProvider.overrideWith(
            (_) => Stream.value(CardsDashboard(cards: cards)),
          ),
        ],
        child: MaterialApp(
          home: StudySetupPage(
            title: 'Malayalam',
            prompts: [for (final card in cards) ...card.prompts],
            studyCards: cards,
            fromLanguage: 'English',
            toLanguage: 'Malayalam',
          ),
        ),
      ),
    );

    await tester.tap(find.text('Recall'));
    await tester.pumpAndSettle();
    expect(find.text('2 available'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Learning'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Relearning'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Retained'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'New'), findsOneWidget);
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'All'))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'New'))
          .selected,
      isFalse,
    );
    expect(find.text('1 out of 2 cards are due now'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(FilterChip, 'Past'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Past'));
    await tester.pump();
    expect(find.text('4 available'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'New'));
    await tester.pump();
    expect(find.text('1 available'), findsOneWidget);
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'All'))
          .selected,
      isFalse,
    );
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'New'))
          .selected,
      isTrue,
    );

    await tester.tap(find.widgetWithText(FilterChip, 'Learning'));
    await tester.pump();
    expect(find.text('2 available'), findsOneWidget);

    await tester.ensureVisible(find.text('Due'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Due'));
    await tester.pump();
    expect(find.text('1 out of 2 cards are due now'), findsOneWidget);
    expect(find.text('1 available'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'All'));
    await tester.pump();
    expect(find.text('2 available'), findsOneWidget);
  });

  testWidgets('recall due count follows the selected front cue', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    final future = now.add(const Duration(days: 1));
    final past = now.subtract(const Duration(minutes: 1));
    CardSchedule schedule(DateTime dueAt) => CardSchedule(
      enabled: true,
      dueAt: dueAt,
      lastReviewedAt: now.subtract(const Duration(days: 1)),
      stability: 1,
      difficulty: 5,
      schedulingState: 'learning',
      learningStep: 0,
      reviewCount: 1,
      lapseCount: 0,
    );
    final card = StudyCard(
      id: 1,
      content: const LanguageCardContent(
        english: 'talent',
        originalScript: 'കഴിവ്',
        transliteration: 'kazhivu',
      ),
      schedules: <StudyCue, CardSchedule>{
        StudyCue.fromLanguage: schedule(future),
        StudyCue.toLanguage: schedule(past),
      },
      reviewHistory: const <StudyCue, List<CardReview>>{},
      suspended: false,
      learningStatus: LearningStatus.learning,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardsDashboardProvider.overrideWith(
            (_) => Stream.value(CardsDashboard(cards: [card])),
          ),
        ],
        child: MaterialApp(
          home: StudySetupPage(
            title: 'Malayalam',
            prompts: card.prompts.toList(),
            studyCards: [card],
            fromLanguage: 'English',
            toLanguage: 'Malayalam',
          ),
        ),
      ),
    );

    await tester.tap(find.text('Recall'));
    await tester.pumpAndSettle();
    expect(find.text('0 out of 1 cards are due now'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Malayalam'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Malayalam'));
    await tester.pump();

    expect(find.text('1 out of 1 cards are due now'), findsOneWidget);
  });

  testWidgets('retained filter uses a recent-recall upper bound', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    final cards = [
      _recallFilterCard(
        id: 1,
        learningStatus: LearningStatus.learning,
        state: 'review',
        lastReviewedAt: now,
        ratings: const [3, 3, 3, 1, 1],
      ),
      _recallFilterCard(
        id: 2,
        learningStatus: LearningStatus.learning,
        state: 'review',
        lastReviewedAt: now,
        ratings: const [3, 3, 3, 3, 3],
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardsDashboardProvider.overrideWith(
            (_) => Stream.value(CardsDashboard(cards: cards)),
          ),
        ],
        child: MaterialApp(
          home: StudySetupPage(
            title: 'Malayalam',
            prompts: [for (final card in cards) ...card.prompts],
            studyCards: cards,
            fromLanguage: 'English',
            toLanguage: 'Malayalam',
          ),
        ),
      ),
    );

    await tester.tap(find.text('Recall'));
    await tester.pumpAndSettle();
    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey('retained-recall-slider')),
    );
    expect(slider.divisions, 5);
    expect(find.text('0–100%'), findsOneWidget);
    expect(find.text('2 available'), findsOneWidget);
    expect(find.text('0 out of 2 cards are due now'), findsOneWidget);

    slider.onChanged!(60);
    await tester.pump();
    expect(find.text('0–60%'), findsOneWidget);
    expect(find.text('1 available'), findsOneWidget);
    expect(find.text('0 out of 1 cards are due now'), findsOneWidget);
  });

  testWidgets('restores the last setup independently for a study source', (
    tester,
  ) async {
    final card = StudyCard(
      id: 1,
      content: const LanguageCardContent(
        english: 'talent',
        originalScript: 'കഴിവ്',
        transliteration: 'kazhivu',
      ),
      schedules: const <StudyCue, CardSchedule>{
        StudyCue.fromLanguage: CardSchedule.initial(enabled: true),
        StudyCue.toLanguage: CardSchedule.initial(enabled: true),
        StudyCue.transliteration: CardSchedule.initial(enabled: true),
      },
      reviewHistory: const <StudyCue, List<CardReview>>{},
      suspended: false,
      learningStatus: LearningStatus.learning,
    );

    Widget setup(String preferenceKey) => ProviderScope(
      overrides: [
        cardAudioRepositoryProvider.overrideWithValue(null),
        cardsDashboardProvider.overrideWith(
          (_) => Stream.value(CardsDashboard(cards: [card])),
        ),
      ],
      child: MaterialApp(
        home: StudySetupPage(
          title: 'Nouns',
          preferenceKey: preferenceKey,
          prompts: card.prompts.toList(),
          studyCards: [card],
          fromLanguage: 'English',
          toLanguage: 'Malayalam',
        ),
      ),
    );

    await tester.pumpWidget(setup('tag:nouns'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recall'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fast'));
    await tester.ensureVisible(find.widgetWithText(FilterChip, 'Past'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Past'));
    await tester.ensureVisible(find.text('Transliteration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transliteration'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(setup('tag:nouns'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<SegmentedButton<StudyMode>>(
            find.byType(SegmentedButton<StudyMode>),
          )
          .selected,
      {StudyMode.recall},
    );
    expect(
      tester
          .widget<SegmentedButton<RecallPresentation>>(
            find.byType(SegmentedButton<RecallPresentation>),
          )
          .selected,
      {RecallPresentation.fast},
    );
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Past'))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, 'Transliteration'),
          )
          .selected,
      isTrue,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(setup('tag:verbs'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SegmentedButton<StudyMode>>(
            find.byType(SegmentedButton<StudyMode>),
          )
          .selected,
      {StudyMode.study},
    );
  });

  for (final type in ['Word', 'Verb', 'Phrase', 'Script']) {
    testWidgets('$type supports handwriting practice', (tester) async {
      final card = StudyCard(
        id: 90,
        modelTypeName: type,
        content: const LanguageCardContent(
          english: 'I am at home',
          originalScript: '我在家。',
          transliteration: 'wǒ zài jiā',
        ),
        schedules: {
          for (final cue in StudyCue.values)
            cue: const CardSchedule.initial(enabled: true),
        },
        reviewHistory: {for (final cue in StudyCue.values) cue: <CardReview>[]},
        suspended: false,
        learningStatus: LearningStatus.learning,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cardAudioRepositoryProvider.overrideWithValue(null),
            cardsDashboardProvider.overrideWith(
              (_) => Stream.value(CardsDashboard(cards: [card])),
            ),
          ],
          child: MaterialApp(
            home: StudySetupPage(
              title: type,
              prompts: card.prompts.toList(),
              studyCards: [card],
              fromLanguage: 'English',
              toLanguage: 'Chinese',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Draw'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start drawing'));
      await tester.pumpAndSettle();
      expect(find.text('我在家。'), findsOneWidget);
      expect(find.textContaining('wǒ zài jiā'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('script-drawing-canvas')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Quit drawing practice'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Recall'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recall'));
      await tester.pumpAndSettle();
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('Fast'), findsOneWidget);
      await tester.tap(find.text('Write'));
      await tester.ensureVisible(
        find.widgetWithText(ChoiceChip, 'Eng. + Transli.'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Eng. + Transli.'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Start recall'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start recall'));
      await tester.pumpAndSettle();
      expect(find.text('Write your answer'), findsOneWidget);
      expect(find.text('I am at home'), findsOneWidget);
      expect(find.text('wǒ zài jiā'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('script-drawing-canvas')),
        findsOneWidget,
      );
      expect(find.text('我在家。'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('script drawing reuses study sheet filters and card count', (
    tester,
  ) async {
    final learning = _scriptCard(
      id: 1,
      letter: 'ക',
      learningStatus: LearningStatus.learning,
    );
    final learnt = _scriptCard(
      id: 2,
      letter: 'ഖ',
      learningStatus: LearningStatus.learnt,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(_FakeAudioRepository()),
          cardsDashboardProvider.overrideWith(
            (_) => Stream.value(CardsDashboard(cards: [learning, learnt])),
          ),
        ],
        child: MaterialApp(
          home: StudySetupPage(
            title: 'Script',
            prompts: [...learning.prompts, ...learnt.prompts],
            studyCards: [learning, learnt],
            fromLanguage: 'English',
            toLanguage: 'Malayalam',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Study sheet'), findsOneWidget);
    expect(find.text('Draw'), findsOneWidget);
    expect(find.text('Which cards?'), findsOneWidget);
    expect(find.text('How many cards?'), findsOneWidget);
    expect(find.text('All letters on one page'), findsNothing);
    expect(find.text('Choose the order'), findsNothing);
    expect(find.text('1 available'), findsOneWidget);
    await tester.tap(find.text('Draw'));
    await tester.pumpAndSettle();

    expect(find.text('Which cards?'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Current'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Past'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'All'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Learning'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Relearning'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Retained'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'New'), findsOneWidget);
    expect(find.text('Due'), findsOneWidget);
    expect(find.text('How many cards?'), findsOneWidget);
    expect(find.text('How many letters?'), findsNothing);
    expect(find.text('Choose the order'), findsNothing);
    expect(find.text('1 available'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'Past'));
    await tester.pumpAndSettle();
    expect(find.text('2 available'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start drawing'));
    await tester.pumpAndSettle();

    final firstLetter = tester
        .widget<Text>(
          find.byKey(const ValueKey<String>('draw-practice-letter')),
        )
        .data!;
    expect(firstLetter, isIn(['ക', 'ഖ']));
    expect(find.byTooltip('Play pronunciation'), findsOneWidget);
    await tester.tap(find.byTooltip('Hide character'));
    await tester.pumpAndSettle();
    expect(find.text(firstLetter).hitTestable(), findsNothing);
    expect(find.byTooltip('Play pronunciation'), findsOneWidget);
    await tester.tap(find.byTooltip('Show character'));
    await tester.pumpAndSettle();
    expect(find.text(firstLetter).hitTestable(), findsOneWidget);
    expect(find.text('CARD 1 OF 2'), findsOneWidget);
    final erase = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.delete_outline),
    );
    expect(erase.onPressed, isNull);
    await tester.drag(
      find.byKey(const ValueKey<String>('script-drawing-canvas')),
      const Offset(80, 80),
    );
    await tester.pump();
    final drawingPaint = tester.widget<CustomPaint>(
      find.byKey(const ValueKey<String>('script-drawing-paint')),
    );
    expect(drawingPaint.painter, isNull);
    expect(drawingPaint.foregroundPainter, isNotNull);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.delete_outline),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byTooltip('Erase'));
    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    expect(find.text(firstLetter == 'ക' ? 'ഖ' : 'ക'), findsOneWidget);
    expect(find.text('CARD 2 OF 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Quit drawing practice'));
    await tester.pumpAndSettle();
    expect(find.text('How do you want to study?'), findsOneWidget);
  });

  testWidgets('script recall offers the same formats and prompts as words', (
    tester,
  ) async {
    final card = _scriptCard(
      id: 1,
      letter: 'ക',
      learningStatus: LearningStatus.learning,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardsDashboardProvider.overrideWith(
            (_) => Stream.value(CardsDashboard(cards: [card])),
          ),
        ],
        child: MaterialApp(
          home: StudySetupPage(
            title: 'Script',
            prompts: card.prompts.toList(),
            studyCards: [card],
            fromLanguage: 'English',
            toLanguage: 'Malayalam',
          ),
        ),
      ),
    );

    await tester.tap(find.text('Recall'));
    await tester.pumpAndSettle();
    expect(find.text('Recall format'), findsOneWidget);
    expect(find.text('Write'), findsOneWidget);
    expect(find.text('Fast'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'English'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Malayalam'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Transliteration'), findsOneWidget);
  });

  testWidgets('recall includes matching cards even when they are not due', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    final staleCard = _languageCard(
      schedule: CardSchedule(
        enabled: true,
        dueAt: now.subtract(const Duration(minutes: 1)),
        lastReviewedAt: now.subtract(const Duration(days: 1)),
        stability: 1,
        difficulty: 5,
        schedulingState: 'review',
        learningStep: null,
        reviewCount: 1,
        lapseCount: 0,
      ),
    );
    final latestCard = _languageCard(
      schedule: CardSchedule(
        enabled: true,
        dueAt: now.add(const Duration(minutes: 10)),
        lastReviewedAt: now,
        stability: 1.2,
        difficulty: 5,
        schedulingState: 'learning',
        learningStep: 1,
        reviewCount: 2,
        lapseCount: 0,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardsDashboardProvider.overrideWith(
            (_) => Stream.value(CardsDashboard(cards: [latestCard])),
          ),
        ],
        child: MaterialApp(
          home: StudySetupPage(
            title: 'Malayalam',
            prompts: staleCard.prompts.toList(),
            studyCards: [staleCard],
            fromLanguage: 'English',
            toLanguage: 'Malayalam',
          ),
        ),
      ),
    );

    await tester.tap(find.text('Recall'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start recall'));
    await tester.pumpAndSettle();

    expect(find.text('talent'), findsOneWidget);
    expect(find.text('Nothing due right now'), findsNothing);
  });

  testWidgets('completed recall returns to setup with refreshed availability', (
    tester,
  ) async {
    final card = _recallFilterCard(
      id: 1,
      learningStatus: LearningStatus.learning,
      state: 'learning',
    );
    var currentCards = [card];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardsDashboardProvider.overrideWith(
            (_) => Stream.value(CardsDashboard(cards: currentCards)),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => StudySetupPage(
                      title: 'Nouns',
                      prompts: card.prompts.toList(),
                      studyCards: [card],
                      fromLanguage: 'English',
                      toLanguage: 'Malayalam',
                    ),
                  ),
                ),
                child: const Text('Noun category'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Noun category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recall'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start recall'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start recall'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End'));
    await tester.pumpAndSettle();
    currentCards = [];
    ProviderScope.containerOf(
      tester.element(find.text('Return to study')),
    ).invalidate(cardsDashboardProvider);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Return to study'));
    await tester.pumpAndSettle();

    expect(find.text('Noun category'), findsNothing);
    expect(find.text('How do you want to study?'), findsOneWidget);
    expect(
      tester
          .widget<SegmentedButton<StudyMode>>(
            find.byType(SegmentedButton<StudyMode>),
          )
          .selected,
      {StudyMode.recall},
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Start recall'),
          )
          .onPressed,
      isNull,
    );
  });
}

StudyCard _languageCard({required CardSchedule schedule}) => StudyCard(
  id: 1,
  content: const LanguageCardContent(
    english: 'talent',
    originalScript: 'കഴിവ്',
    transliteration: 'kazhivu',
  ),
  schedules: <StudyCue, CardSchedule>{StudyCue.fromLanguage: schedule},
  reviewHistory: const <StudyCue, List<CardReview>>{
    StudyCue.fromLanguage: <CardReview>[],
  },
  suspended: false,
  learningStatus: LearningStatus.learning,
);

StudyCard _recallFilterCard({
  required int id,
  required LearningStatus learningStatus,
  required String state,
  DateTime? lastReviewedAt,
  bool due = false,
  List<int> ratings = const <int>[],
}) => StudyCard(
  id: id,
  content: LanguageCardContent(
    english: 'word $id',
    originalScript: 'വാക്ക് $id',
    transliteration: 'vākku $id',
  ),
  schedules: <StudyCue, CardSchedule>{
    StudyCue.fromLanguage: CardSchedule(
      enabled: true,
      dueAt: due
          ? DateTime.now().toUtc().subtract(const Duration(minutes: 1))
          : DateTime.now().toUtc().add(const Duration(days: 30)),
      lastReviewedAt: lastReviewedAt,
      stability: lastReviewedAt == null ? null : 1,
      difficulty: lastReviewedAt == null ? null : 5,
      schedulingState: state,
      learningStep: state == 'review' ? null : 0,
      reviewCount: lastReviewedAt == null ? 0 : 1,
      lapseCount: 0,
    ),
  },
  reviewHistory: <StudyCue, List<CardReview>>{
    StudyCue.fromLanguage: [
      for (final (index, rating) in ratings.indexed)
        CardReview(
          id: '$id-$index',
          reviewedAt: DateTime.utc(2026, 8, 1, 12, index),
          rating: rating,
          elapsedSeconds: 1,
          scheduledSeconds: 1,
        ),
    ],
  },
  suspended: false,
  learningStatus: learningStatus,
);

StudyCard _scriptCard({
  required int id,
  required String letter,
  required LearningStatus learningStatus,
}) => StudyCard(
  id: id,
  content: LanguageCardContent(
    english: 'Letter $id',
    originalScript: letter,
    transliteration: 'letter$id',
    audioUrl: '/audio/letter$id.mp3',
  ),
  schedules: const <StudyCue, CardSchedule>{
    StudyCue.fromLanguage: CardSchedule.initial(enabled: true),
    StudyCue.toLanguage: CardSchedule.initial(enabled: true),
  },
  reviewHistory: const <StudyCue, List<CardReview>>{
    StudyCue.fromLanguage: <CardReview>[],
    StudyCue.toLanguage: <CardReview>[],
  },
  suspended: false,
  learningStatus: learningStatus,
  modelTypeName: 'Script',
);

class _FakeAudioRepository implements CardAudioRepository {
  @override
  Future<Uint8List> fetch(String audioUrl) async => Uint8List(0);
}
