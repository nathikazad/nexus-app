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
      language: 'Malayalam',
      archived: false,
    );
    const card = StudyCard(
      id: 20,
      content: LanguageCardContent(
        english: 'fraud',
        originalScript: 'തട്ടിപ്പ്',
        transliteration: 'thattippu',
      ),
      deckId: 10,
      deckName: 'Malayalam words',
      tags: ['legal'],
      dueAt: null,
      lastReviewedAt: null,
      stability: null,
      difficulty: null,
      schedulingState: 'learning',
      learningStep: null,
      suspended: false,
      reviewCount: 0,
      lapseCount: 0,
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
                    builder: (_) =>
                        const CardDetailsDialog(deck: deck, card: card),
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
    expect(find.text('legal'), findsOneWidget);

    await tester.tap(find.text('Edit card'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });
}
