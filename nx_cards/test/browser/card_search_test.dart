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
      schedules: const {},
      reviewHistory: {
        StudyCue.fromLanguage: [
          for (
            var i = 0;
            i < (status == LearningStatus.active ? (id == 1 ? 1 : 8) : 0);
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
      final word = card(1, LearningStatus.active);
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
    'search spans statuses, stays in category and restores tab and scroll',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final dashboard = CardsDashboard(
        cards: [
          card(1, LearningStatus.active),
          card(2, LearningStatus.active),
          for (var i = 3; i <= 20; i++) card(i, LearningStatus.inactive),
          card(99, LearningStatus.active, category: 'Adjective'),
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
      await tester.ensureVisible(find.text('Future  18'));
      await tester.tap(find.text('Future  18'));
      await tester.pumpAndSettle();
      final originalScroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      originalScroll.position.jumpTo(300);
      await tester.pumpAndSettle();
      final offset = originalScroll.position.pixels;
      expect(offset, greaterThan(0));
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
      expect(find.text('Current'), findsOneWidget);
      expect(find.text('Past'), findsOneWidget);
      expect(find.text('Future'), findsNWidgets(18));
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
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller, isNull);
      final context = tester.element(find.byType(TabBar));
      expect(DefaultTabController.of(context).index, 3);
      expect(originalScroll.position.pixels, offset);
      expect(tester.takeException(), isNull);
    },
  );
}
