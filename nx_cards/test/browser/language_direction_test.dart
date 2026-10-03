import 'package:nx_cards/progress/progress_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nx_cards/scheduling/language_direction.dart';
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
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'direction labels identify both languages, with a readable fallback',
    () {
      expect(compactLanguageLabel('Chinese'), '中');
      expect(compactLanguageLabel('Tamil'), 'தமிழ்');
      expect(compactLanguageLabel('Malayalam'), 'മലയാളം');
      expect(compactLanguageLabel('English'), 'EN');
      expect(compactLanguageLabel('Spanish'), 'Spanish');
    },
  );

  testWidgets('audio is the third independent direction', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: LanguageDirectionButton(language: 'Chinese')),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Recall direction: Meaning'));
    await tester.pumpAndSettle();
    expect(find.text('Meaning'), findsNWidgets(2));
    expect(find.text('Script'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('recall-direction-sound')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Recall direction: Sound'), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LanguageDirectionButton)),
    );
    expect(
      container.read(languageDirectionProvider('Chinese')),
      RecallComponent.sound,
    );
  });

  testWidgets(
    'Current averages selected directions and only Current has a slider',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final dashboard = CardsDashboard(
        cards: [
          hierarchy
              .card(1, [
                ['Word'],
              ], language: 'Chinese')
              .copyWith(
                content: sample(1, 6).content,
                schedules: sample(1, 6).schedules,
                reviewHistory: sample(1, 6).reviewHistory,
                learningStatus: LearningStatus.recall,
              ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sourceProgressCardsProvider.overrideWith((ref, source) async => []),

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
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Recall'), findsOneWidget);
      expect(find.byKey(const ValueKey('practice-select')), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
      expect(find.text('60%'), findsOneWidget);
      expect(find.byKey(const ValueKey('current-retention')), findsNothing);
      expect(find.text('Weak (1)', findRichText: true), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('current-filter-toggle')));
      await tester.pumpAndSettle();
      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('current-retention')),
      );
      expect(slider.value, .8);
      slider.onChanged!(1);
      await tester.pumpAndSettle();
      expect(find.byType(DirectionChoices), findsNothing);
      expect(find.text('60%'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.text('60%'), findsOneWidget);
      expect(find.byKey(const ValueKey('current-retention')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('open-backlog')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('current-retention')), findsNothing);
      expect(find.text('No cards in Backlog.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
