import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/browser/language/language_page.dart';
import 'package:nx_cards/scheduling/review_progression.dart';
import '../study/study_setup_page_test.dart' show sample;
import 'category_hierarchy_test.dart' as hierarchy;

void main() {
  testWidgets('one direction controls category totals and the opened list', (
    tester,
  ) async {
    final dashboard = CardsDashboard(
      cards: [
        hierarchy
            .card(1, [
              ['Word'],
            ], language: 'Chinese')
            .copyWith(
              content: sample(1, 8).content,
              schedules: sample(1, 8).schedules,
              reviewHistory: sample(1, 8).reviewHistory,
              learningStatus: LearningStatus.active,
            ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardsCollectionProvider.overrideWith(
            (ref, source) => Stream.value(dashboard),
          ),
          reviewProgressionSettingsProvider.overrideWith(
            (ref) async => const ReviewProgressionSettings(),
          ),
        ],
        child: const MaterialApp(home: LanguagePage(language: 'Chinese')),
      ),
    );
    await tester.pumpAndSettle();
    Finder metric(String name, String count) => find.descendant(
      of: find.byKey(ValueKey('language-category-word-$name')),
      matching: find.text(count),
    );
    expect(metric('past', '1'), findsOneWidget);
    expect(metric('upcoming', '0'), findsOneWidget);
    await tester.tap(find.byTooltip('Recall direction: English → Chinese'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chinese → English'));
    await tester.pumpAndSettle();
    expect(metric('past', '0'), findsOneWidget);
    expect(metric('current', '1'), findsOneWidget);
    await tester.tap(find.byTooltip('All cards'));
    await tester.pumpAndSettle();
    expect(find.text('Current  1'), findsOneWidget);
    expect(find.text('Past  0'), findsOneWidget);
    await tester.tap(find.text('Current  1'));
    await tester.pumpAndSettle();
    expect(find.text('word 1'), findsOneWidget);
  });
}
