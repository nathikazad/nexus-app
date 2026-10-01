import 'package:nx_cards/study/language/drawing/native_drawing_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/browser/language/language_page.dart';
import 'package:nx_cards/study/language/language_study_page.dart';
import 'package:nx_cards/study/language/drawing/script_draw_practice_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../study/study_setup_page_test.dart' show sample;

void main() {
  testWidgets(
    'Practice selects on the existing list and opens only selected cards',
    (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        NativeDrawingSession.channel,
        (call) async => call.method == 'available' ? false : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          NativeDrawingSession.channel,
          null,
        ),
      );
      SharedPreferences.setMockInitialValues({});
      final cards = [sample(1, 0), sample(2, 0), sample(3, 0)];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cardsDashboardProvider.overrideWith(
              (ref) => Stream.value(CardsDashboard(cards: cards)),
            ),
            cardsCollectionProvider.overrideWith(
              (ref, source) => Stream.value(CardsDashboard(cards: cards)),
            ),
          ],
          child: const MaterialApp(
            home: LanguageCategoryPage(
              category: 'All',
              allCards: true,
              language: 'Chinese',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('practice-select')));
      await tester.pumpAndSettle();
      expect(find.byType(LanguageCategoryPage), findsOneWidget);
      expect(find.text('0 selected'), findsOneWidget);
      expect(find.byKey(const ValueKey('top-practice')), findsOneWidget);
      expect(find.byTooltip('Recall'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('select-card-2')));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('top-practice')));
      await tester.pumpAndSettle();
      final sheet = tester.widget<LanguageStudyPage>(
        find.byType(LanguageStudyPage),
      );
      expect(sheet.cards.map((c) => c.id), [2]);
      expect(sheet.cards.single.learningStatus, LearningStatus.recall);
      expect(find.text('How many cards?'), findsNothing);
      await tester.tap(find.text('Draw'));
      await tester.pumpAndSettle();
      final drawing = tester.widget<ScriptDrawPracticePage>(
        find.byType(ScriptDrawPracticePage),
      );
      expect(drawing.cards.map((c) => c.id), [2]);
      expect(find.text('字2'), findsOneWidget);
      await tester.tap(find.byTooltip('Study sheet'));
      await tester.pumpAndSettle();
      expect(find.byType(LanguageStudyPage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cancel-practice-selection')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('top-practice')), findsNothing);
      expect(find.byTooltip('Recall'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
