import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/composition/cards_composition.dart';
import 'package:nx_cards/core/theme/app_theme.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/features/study/study_screen.dart';

void main() {
  testWidgets('opens examples from a revealed language card', (tester) async {
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
    const deck = CardDeck(
      id: 10,
      name: 'Malayalam words',
      description: '',
      fromLanguage: 'English',
      toLanguage: 'Malayalam',
      archived: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardsDashboardProvider.overrideWith(
            (_) => Stream.value(
              CardsDashboard(decks: const [deck], cards: [card]),
            ),
          ),
        ],
        child: MaterialApp(
          theme: buildRecallTheme(),
          home: StudyScreen(
            title: 'Malayalam words',
            prompts: <StudyPrompt>[
              StudyPrompt(card: card, cue: StudyCue.fromLanguage),
            ],
          ),
        ),
      ),
    );

    expect(find.text('അത് ഒരു തട്ടിപ്പായിരുന്നു.'), findsNothing);

    await tester.tap(find.text('Show answer'));
    await tester.pumpAndSettle();

    expect(find.text('fraud'), findsOneWidget);
    expect(find.text('തട്ടിപ്പ്'), findsOneWidget);
    expect(find.text('thattippu'), findsOneWidget);
    expect(find.text('അത് ഒരു തട്ടിപ്പായിരുന്നു.'), findsNothing);
    expect(
      find.ancestor(of: find.text('Examples'), matching: find.byType(Card)),
      findsOneWidget,
    );
    expect(find.text('Edit card'), findsNothing);
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);

    await tester.tap(find.byTooltip('Card stats'));
    await tester.pumpAndSettle();
    expect(find.text('How well you know this card'), findsOneWidget);
    expect(find.byTooltip('Edit card'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Examples'));
    await tester.pumpAndSettle();

    expect(find.text('Examples'), findsOneWidget);
    expect(find.text('അത് ഒരു തട്ടിപ്പായിരുന്നു.'), findsOneWidget);
    expect(find.text('athu oru thattippayirunnu'), findsOneWidget);
    expect(find.text('It was a fraud.'), findsOneWidget);
  });

  testWidgets('shows the Space shortcut only on desktop', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final card = StudyCard(
        id: 21,
        content: const LanguageCardContent(
          english: 'talent',
          originalScript: 'കഴിവ്',
          transliteration: 'kazhivu',
        ),
        deckId: 10,
        deckName: 'Malayalam words',
        schedules: const {
          StudyCue.fromLanguage: CardSchedule.initial(enabled: true),
        },
        reviewHistory: const {},
        suspended: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cardAudioRepositoryProvider.overrideWithValue(null),
            cardsDashboardProvider.overrideWith(
              (_) => Stream.value(const CardsDashboard(decks: [], cards: [])),
            ),
          ],
          child: MaterialApp(
            home: StudyScreen(
              title: 'Malayalam words',
              prompts: [StudyPrompt(card: card, cue: StudyCue.fromLanguage)],
            ),
          ),
        ),
      );

      expect(find.text('Show answer   Space'), findsOneWidget);
      expect(find.text('Show answer'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
