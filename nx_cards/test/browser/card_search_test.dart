import 'package:nx_cards/browser/data/models/library_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/browser/card_list/card_search.dart';
import 'package:nx_cards/browser/language/language_page.dart';

StudyCard card(int id, LearningStatus status, {String category = 'Noun'}) =>
    StudyCard(
      id: id,
      content: LanguageCardContent(
        english: 'after $id',
        originalScript: '之后$id',
        transliteration: 'zhī hòu',
      ),
      schedules: {
        for (final direction in StudyCue.values)
          direction: CardSchedule.initial(
            enabled: direction != StudyCue.backToFront,
          ),
      },
      reviewHistory: {
        StudyCue.meaningToScript: [
          for (
            var i = 0;
            i < (status == LearningStatus.recall ? (id == 1 ? 1 : 8) : 0);
            i++
          )
            CardReview(
              id: '$id-$i',
              reviewedAt: DateTime.utc(2026, 1, i + 1),
              rating: 3,
              elapsedSeconds: 0,
              scheduledSeconds: 0,
            ),
        ],
      },
      suspended: false,
      learningStatus: status,
      modelTypeName: 'Word',
      tags: {
        'Language': ['Chinese'],
        'Word Category': [category],
      },
    );

void main() {
  test(
    'matches Chinese, English and pinyin with or without tones and spaces',
    () {
      final word = card(1, LearningStatus.recall);
      for (final query in [
        '之后',
        'AFTER',
        'zhihou',
        'zhīhòu',
        'zhi\u0304 ho\u0300u',
        ' ',
      ]) {
        expect(cardMatchesSearch(word, query), isTrue, reason: query);
      }
      expect(cardMatchesSearch(word, 'before'), isFalse);
    },
  );

  testWidgets(
    'search sits before Practice, spans statuses and stays in category',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final dashboard = CardsDashboard(
        cards: [
          card(1, LearningStatus.recall),
          card(2, LearningStatus.recall),
          for (var i = 3; i <= 20; i++) card(i, LearningStatus.future),
          card(99, LearningStatus.recall, category: 'Adjective'),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cardsCollectionProvider.overrideWith(
              (ref, source) =>
                  Stream.fromFuture(ref.watch(cardsDashboardProvider.future)),
            ),
            cardsSourcesProvider.overrideWith(
              (ref) => Stream.fromFuture(
                ref.watch(cardsDashboardProvider.future).then(summarizeLibrary),
              ),
            ),
            cardsDashboardProvider.overrideWith((_) => Stream.value(dashboard)),
          ],
          child: const MaterialApp(
            home: LanguageCategoryPage(category: 'Noun', language: 'Chinese'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.byTooltip('Search all cards')).dx,
        lessThan(
          tester.getCenter(find.byKey(const ValueKey('practice-select'))).dx,
        ),
      );
      await tester.tap(find.byTooltip('Search all cards'));
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsNothing);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      final input = find.byKey(const ValueKey('card-search-field'));
      await tester.enterText(input, 'zhihou');
      await tester.pumpAndSettle();
      expect(find.text('after 1'), findsOneWidget);
      expect(find.text('after 2'), findsOneWidget);
      expect(find.text('after 3'), findsOneWidget);
      expect(find.text('after 99'), findsNothing);
      expect(find.text('Current'), findsNWidgets(2));
      expect(
        find.text('Backlog').evaluate().length,
        inExclusiveRange(0, 18),
      ); // Offscreen rows are built lazily.
      await tester.enterText(input, '之后2');
      await tester.pumpAndSettle();
      expect(find.text('after 2'), findsOneWidget);
      expect(find.text('after 1'), findsNothing);
      await tester.enterText(input, 'missing');
      await tester.pumpAndSettle();
      expect(find.text('No matching cards.'), findsOneWidget);
      await tester.tap(find.byTooltip('Close search'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TabBar), findsNothing);
      expect(find.text('after 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
