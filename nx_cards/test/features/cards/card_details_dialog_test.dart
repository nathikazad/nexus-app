import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/features/cards/card_details_dialog.dart';

void main() {
  testWidgets('shows language card details and returns an edit intent', (
    tester,
  ) async {
    const deck = CardDeck(
      id: 10,
      name: 'Malayalam words',
      description: '',
      fromLanguage: 'English',
      toLanguage: 'Malayalam',
      archived: false,
    );
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
    bool? result;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  result = await showDialog<bool>(
                    context: context,
                    builder: (_) => CardDetailsDialog(deck: deck, card: card),
                  );
                },
                child: const Text('Open card'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open card'));
    await tester.pumpAndSettle();

    expect(find.text('Card details'), findsOneWidget);
    expect(find.text('fraud'), findsOneWidget);
    expect(find.text('തട്ടിപ്പ്'), findsOneWidget);
    expect(find.text('thattippu'), findsOneWidget);
    expect(find.text('EXAMPLES'), findsOneWidget);
    expect(find.text('അത് ഒരു തട്ടിപ്പായിരുന്നു.'), findsOneWidget);
    expect(find.text('It was a fraud.'), findsOneWidget);

    await tester.tap(find.text('Edit card'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });
}
