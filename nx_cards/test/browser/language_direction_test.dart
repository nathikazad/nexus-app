import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/browser/language/language_page.dart';
import 'package:nx_cards/scheduling/review_progression.dart';
import '../study/study_setup_page_test.dart' show sample;

void main() {
  testWidgets('one direction controls category totals and the opened list', (
    tester,
  ) async {
    final dashboard = CardsDashboard(cards: [sample(1, 8)]);
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
      of: find.byKey(ValueKey('language-category-all-$name')),
      matching: find.text(count),
    );
    expect(metric('past', '1'), findsOneWidget);
    expect(metric('upcoming', '0'), findsOneWidget);
    await tester.tap(find.byTooltip('Recall direction: English → Chinese'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chinese → English'));
    await tester.pumpAndSettle();
    expect(metric('past', '0'), findsOneWidget);
    expect(metric('upcoming', '1'), findsOneWidget);
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('Upcoming  1'), findsOneWidget);
    expect(find.text('Past  0'), findsOneWidget);
    expect(find.text('word 1'), findsOneWidget);
  });
}
