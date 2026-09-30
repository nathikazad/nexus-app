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
    await tester.tap(find.byTooltip('Recall direction: English → Chinese'));
    await tester.pumpAndSettle();
    expect(find.text('EN → 中'), findsNWidgets(2));
    expect(find.text('中 → EN'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('recall-direction-from_audio')));
    await tester.pumpAndSettle();
    expect(
      find.byTooltip('Recall direction: Chinese audio → Chinese'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LanguageDirectionButton)),
    );
    expect(
      container.read(languageDirectionProvider('Chinese')),
      StudyCue.fromAudio,
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
                content: sample(1, 8).content,
                schedules: sample(1, 8).schedules,
                reviewHistory: sample(1, 8).reviewHistory,
                learningStatus: LearningStatus.recall,
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
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.text('Current  1'), findsOneWidget);
      expect(find.text('33%'), findsOneWidget);
      expect(find.byKey(const ValueKey('current-retention')), findsNothing);
      expect(
        find.text('Weak (1) · All directions', findRichText: true),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('current-filter-toggle')));
      await tester.pumpAndSettle();
      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('current-retention')),
      );
      expect(slider.value, .8);
      slider.onChanged!(1);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('direction-from_audio')));
      await tester.pumpAndSettle();
      expect(find.text('50%'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('direction-to_language')),
      );
      await tester.tap(find.byKey(const ValueKey('direction-to_language')));
      await tester.pumpAndSettle();
      expect(find.text('100%'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('direction-from_language')),
      );
      await tester.tap(find.byKey(const ValueKey('direction-from_language')));
      await tester.pumpAndSettle();
      expect(
        find.text('100%'),
        findsOneWidget,
      ); // Last direction cannot be cleared.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.text('100%'), findsOneWidget);
      expect(find.byKey(const ValueKey('current-retention')), findsNothing);
      await tester.tap(find.text('Upcoming  0'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('current-retention')), findsNothing);
      await tester.tap(find.text('Backlog  0'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('current-retention')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
