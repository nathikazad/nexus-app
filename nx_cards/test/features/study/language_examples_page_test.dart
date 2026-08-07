import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/composition/cards_composition.dart';
import 'package:nx_cards/core/theme/app_theme.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/features/study/study_screen.dart';

void main() {
  testWidgets('opens examples from a revealed forward review card', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final card = StudyCard(
      id: 20,
      content: const LanguageCardContent(
        english: 'fraud',
        originalScript: 'തട്ടിപ്പ്',
        transliteration: 'thattippu',
        examples: <LanguageExample>[
          LanguageExample(
            text: 'അത് ഒരു തട്ടിപ്പായിരുന്നു.',
            transliteration: 'athu oru thattippayirunnu',
            translation: 'It was a fraud.',
          ),
        ],
      ),
      deckId: 10,
      deckName: 'Malayalam words',
      tags: const <String>[],
      schedules: const <StudyDirection, CardSchedule>{
        StudyDirection.frontToBack: CardSchedule.initial(enabled: true),
      },
      reviewHistory: const <StudyDirection, List<CardReview>>{
        StudyDirection.frontToBack: <CardReview>[],
      },
      suspended: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [cardAudioRepositoryProvider.overrideWithValue(null)],
        child: MaterialApp(
          theme: buildRecallTheme(),
          home: StudyScreen(
            title: 'Malayalam words',
            prompts: <StudyPrompt>[
              StudyPrompt(card: card, direction: StudyDirection.frontToBack),
            ],
          ),
        ),
      ),
    );

    expect(find.text('View examples (1)'), findsNothing);

    await tester.tap(find.text('Show answer   Space'));
    await tester.pumpAndSettle();

    expect(find.text('View examples (1)'), findsOneWidget);
    expect(find.text('അത് ഒരു തട്ടിപ്പായിരുന്നു.'), findsNothing);

    await tester.tap(find.text('View examples (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Examples'), findsOneWidget);
    expect(find.text('തട്ടിപ്പ്'), findsOneWidget);
    expect(find.text('thattippu'), findsOneWidget);
    expect(find.text('അത് ഒരു തട്ടിപ്പായിരുന്നു.'), findsOneWidget);
    expect(find.text('athu oru thattippayirunnu'), findsOneWidget);
    expect(find.text('It was a fraud.'), findsOneWidget);
  });
}
