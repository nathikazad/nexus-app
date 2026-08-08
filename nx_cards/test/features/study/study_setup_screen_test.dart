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
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [cardAudioRepositoryProvider.overrideWithValue(null)],
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
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [cardAudioRepositoryProvider.overrideWithValue(null)],
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
}
