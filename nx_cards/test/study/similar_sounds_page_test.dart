import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/audio/audio_providers.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/browser/language/language_page.dart';
import 'similar_sounds_test.dart' show soundCard;

void main() {
  testWidgets(
    'Chinese Explore opens grouped Current words; absent for other languages',
    (tester) async {
      final cards = [
        soundCard(1, 'guó').copyWith(
          content: (soundCard(1, 'guó').content as LanguageCardContent)
              .copyWith(similarWordGroups: ['My contrast']),
        ),
        soundCard(2, 'guǒ'),
        soundCard(3, 'guò', status: LearningStatus.practice),
        soundCard(4, 'gǒu', status: LearningStatus.future),
      ];
      Future<void> show(String language) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cardsCollectionProvider.overrideWith(
                (ref, source) => Stream.value(CardsDashboard(cards: cards)),
              ),
              cardAudioRepositoryProvider.overrideWithValue(null),
            ],
            child: MaterialApp(home: LanguagePage(language: language)),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show('Chinese');
      expect(find.text('Explore'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('explore-similar-sounds')));
      await tester.pumpAndSettle();
      expect(find.byType(Tab), findsNothing);
      expect(find.text('Tones and meanings'), findsNothing);
      expect(find.text('My contrast'), findsOneWidget);
      await tester.tap(find.text('My contrast'));
      await tester.pumpAndSettle();
      expect(find.text('meaning 1'), findsOneWidget);
      expect(find.text('meaning 2'), findsNothing);
      expect(find.text('meaning 3'), findsNothing);
      expect(find.text('meaning 4'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await show('Tamil');
      expect(find.text('Explore'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
