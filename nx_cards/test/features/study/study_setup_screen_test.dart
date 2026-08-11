import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/composition/cards_composition.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/features/study/study_setup_screen.dart';

void main() {
  testWidgets('configures a transliteration-cue session', (tester) async {
    final card = StudyCard(
      id: 1,
      content: const LanguageCardContent(
        english: 'talent',
        originalScript: 'കഴിവ്',
        transliteration: 'kazhivu',
      ),
      deckId: 7,
      deckName: 'Malayalam',
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
            (_) => Stream.value(CardsDashboard(decks: const [], cards: [card])),
          ),
        ],
        child: MaterialApp(
          home: StudySetupScreen(
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
    final english = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'English'),
    );
    final learning = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Learning'),
    );
    final learnt = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Learnt'),
    );
    expect(english.selected, isTrue);
    expect(learning.selected, isTrue);
    expect(learnt.selected, isFalse);
    expect(find.text('What should be in back?'), findsNothing);
    await tester.tap(find.text('Transliteration'));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start recall'));
    await tester.pumpAndSettle();

    expect(find.text('kazhivu'), findsOneWidget);
  });

  testWidgets('offers an AI voice mode for the selected deck', (tester) async {
    final card = StudyCard(
      id: 1,
      content: const LanguageCardContent(
        english: 'talent',
        originalScript: 'കഴിവ്',
        transliteration: 'kazhivu',
      ),
      deckId: 7,
      deckName: 'Malayalam',
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
            (_) => Stream.value(CardsDashboard(decks: const [], cards: [card])),
          ),
        ],
        child: MaterialApp(
          home: StudySetupScreen(
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

    expect(find.text('What should AI ask you?'), findsOneWidget);
    expect(find.text('How many cards?'), findsOneWidget);
    expect(find.text('Choose the order'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pump();
    expect(find.text('Start AI tutor'), findsOneWidget);
  });

  testWidgets('revalidates a stale setup queue before starting recall', (
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
            (_) => Stream.value(
              CardsDashboard(decks: const [], cards: [latestCard]),
            ),
          ),
        ],
        child: MaterialApp(
          home: StudySetupScreen(
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
    await tester.tap(find.text('English'));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start recall'));
    await tester.pumpAndSettle();

    expect(find.text('Nothing due right now'), findsOneWidget);
    expect(find.text('talent'), findsNothing);
    expect(find.text('How do you want to study?'), findsOneWidget);
  });
}

StudyCard _languageCard({required CardSchedule schedule}) => StudyCard(
  id: 1,
  content: const LanguageCardContent(
    english: 'talent',
    originalScript: 'കഴിവ്',
    transliteration: 'kazhivu',
  ),
  deckId: 7,
  deckName: 'Malayalam',
  schedules: <StudyCue, CardSchedule>{StudyCue.fromLanguage: schedule},
  reviewHistory: const <StudyCue, List<CardReview>>{
    StudyCue.fromLanguage: <CardReview>[],
  },
  suspended: false,
  learningStatus: LearningStatus.learning,
);
