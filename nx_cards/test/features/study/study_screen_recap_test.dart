import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/composition/cards_composition.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/features/study/study_screen.dart';

void main() {
  testWidgets('recall completion recaps every word in all three forms', (
    tester,
  ) async {
    final card = StudyCard(
      id: 1,
      content: const LanguageCardContent(
        english: 'talent',
        originalScript: 'കഴിവ്',
        transliteration: 'kazhivu',
      ),
      schedules: const {
        StudyCue.fromLanguage: CardSchedule.initial(enabled: true),
      },
      reviewHistory: const {},
      suspended: false,
      learningStatus: LearningStatus.learning,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardsDashboardProvider.overrideWith(
            (_) => Stream.value(const CardsDashboard(cards: [])),
          ),
        ],
        child: MaterialApp(
          home: StudyScreen(
            title: 'Malayalam',
            prompts: [StudyPrompt(card: card, cue: StudyCue.fromLanguage)],
          ),
        ),
      ),
    );
    await tester.tap(find.text('End'));
    await tester.pumpAndSettle();

    expect(find.text('WORDS'), findsOneWidget);
    expect(find.text('talent'), findsOneWidget);
    expect(find.text('കഴിവ്'), findsOneWidget);
    expect(find.text('kazhivu'), findsOneWidget);
    expect(find.text('NOT REVIEWED'), findsOneWidget);
  });
}
