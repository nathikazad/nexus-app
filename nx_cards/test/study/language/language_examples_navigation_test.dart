import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/audio/audio_providers.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/browser/card_details_page.dart';
import 'package:nx_cards/study/language/language_examples.dart';

void main() {
  testWidgets(
    'only original example text opens details and returns to session',
    (tester) async {
      const example = LanguageExample(
        cardId: 2,
        text: '学生',
        transliteration: 'xuésheng',
        translation: 'student',
      );
      final card = StudyCard(
        id: 2,
        content: const LanguageCardContent(
          originalScript: '学生',
          transliteration: 'xuésheng',
          english: 'student',
        ),
        schedules: {},
        reviewHistory: {},
        suspended: false,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cardAudioRepositoryProvider.overrideWithValue(null),
            cardsDashboardProvider.overrideWith(
              (_) => Stream.value(CardsDashboard(cards: [card])),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: LanguageExamples(
                examples: [example],
                audioRepository: null,
                audioKeyPrefix: 'recall',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final text in ['xuésheng', 'student']) {
        await tester.tap(find.text(text));
        await tester.pumpAndSettle();
        expect(find.byType(CardDetailsPage), findsNothing);
      }
      await tester.tapAt(
        tester.getTopLeft(find.text('学生')) + const Offset(300, 10),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CardDetailsPage), findsNothing);
      await tester.tap(find.text('学生'));
      await tester.pumpAndSettle();
      expect(find.byType(CardDetailsPage), findsOneWidget);
      Navigator.of(tester.element(find.byType(CardDetailsPage))).pop();
      await tester.pumpAndSettle();
      expect(find.text('学生'), findsOneWidget);
      expect(find.byType(CardDetailsPage), findsNothing);
    },
  );
}
