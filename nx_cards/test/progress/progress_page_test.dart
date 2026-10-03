import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:nx_cards/account/account_session.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/sync/sync_providers.dart';
import 'package:nx_cards/browser/language/language_groups.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nx_cards/app/theme.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/progress/progress_page.dart';
import 'progress_analysis_test.dart' show progressCard, review;

final demoCards = [
  for (var id = 0; id < 12; id++)
    progressCard(id, {
      for (final cue in StudyCue.languageDirections)
        cue: [
          for (var day = id + 1; day <= 30; day++)
            review(day, (day + id + cue.index) % 5 == 0 ? 1 : 3),
        ],
    }, path: id < 6 ? ['Script', 'Basics'] : ['Word', 'Noun']),
];

Future<void> showProgress(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool dark = false,
  List<StudyCard>? cards,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? buildRecallDarkTheme() : buildRecallTheme(),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: RepaintBoundary(
          key: const ValueKey('progress-capture'),
          child: Scaffold(
            appBar: AppBar(title: const Text('Chinese · Progress')),
            body: ProgressView(
              cards: cards ?? demoCards,
              language: 'Chinese',
              preferenceKey: 'test-progress',
              now: DateTime(2026, 9, 30, 18),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, String name) async {
  const directory = String.fromEnvironment('PROGRESS_SCREENSHOT_DIR');
  if (directory.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('progress-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '$directory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    const fonts = String.fromEnvironment('PROGRESS_FONT_DIR');
    if (fonts.isEmpty) return;
    for (final font in {
      'Roboto': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      final loader = FontLoader(font.key)
        ..addFont(
          File(
            '$fonts/${font.value}',
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('phone filters accept arbitrary target and persist separately', (
    tester,
  ) async {
    await showProgress(tester);
    expect(find.byKey(const ValueKey('progress-target')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('progress-target')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('custom-target')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('target-input')), '101');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a number from 0 to 100.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('target-input')), '73');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.text('At least 73%'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('test-progress'), contains('"target":73'));
    expect(prefs.getKeys(), {'test-progress'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('category picker respects a parent and nested subcategory', (
    tester,
  ) async {
    await showProgress(tester);
    await tester.tap(find.byKey(const ValueKey('progress-category')));
    await tester.pumpAndSettle();
    expect(find.text('Script › Basics'), findsOneWidget);
    await tester.tap(find.text('Script › Basics'));
    await tester.pumpAndSettle();
    expect(find.text('Script › Basics'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  for (final setup in [
    (name: 'phone', size: const Size(390, 844), scale: 1.0, dark: false),
    (
      name: 'narrow-large-text',
      size: const Size(320, 740),
      scale: 1.7,
      dark: false,
    ),
    (name: 'tablet', size: const Size(1200, 1000), scale: 1.0, dark: false),
    (name: 'tablet-dark', size: const Size(1024, 900), scale: 1.0, dark: true),
  ]) {
    testWidgets('${setup.name} lays out and supports selecting a day', (
      tester,
    ) async {
      await showProgress(
        tester,
        size: setup.size,
        textScale: setup.scale,
        dark: setup.dark,
      );
      expect(tester.takeException(), isNull);
      await capture(tester, setup.name);
      await tester.ensureVisible(find.byKey(const ValueKey('learning-chart')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('learning-chart')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Daily recalls'));
      await tester.pumpAndSettle();
      await capture(tester, '${setup.name}-charts');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('empty history remains usable', (tester) async {
    await showProgress(tester, cards: []);
    expect(find.textContaining('No recalls yet'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('progress-total'))).data,
      '0',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('trimmed page switches both charts to week and month', (
    tester,
  ) async {
    await showProgress(tester);
    expect(find.text('Recall type'), findsNothing);
    expect(find.byKey(const ValueKey('progress-direction')), findsNothing);
    expect(find.text('Percent'), findsNothing);
    expect(find.textContaining('First reached target'), findsNothing);
    expect(find.text('How progress is calculated'), findsNothing);
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(find.text('Weekly recalls'), findsOneWidget);
    expect(find.text('Net change'), findsOneWidget);
    await tester.ensureVisible(find.text('Month'));
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(find.text('Monthly recalls'), findsOneWidget);
    expect(find.text('Daily recalls'), findsNothing);
    await tester.ensureVisible(find.text('Monthly recalls'));
    await tester.pumpAndSettle();
    await capture(tester, 'phone-monthly');
    expect(tester.takeException(), isNull);
    expect(
      (await SharedPreferences.getInstance()).getString('test-progress'),
      contains('"interval":"month"'),
    );
  });

  testWidgets('bar tooltips keep learning and recall selections independent', (
    tester,
  ) async {
    await showProgress(tester, size: const Size(1200, 1500));
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    String tooltip(String key) => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(Text),
          ),
        )
        .data!;
    final originalRecall = tooltip('recall-tooltip');
    final learningChart = find.byKey(const ValueKey('learning-chart'));
    await tester.ensureVisible(learningChart);
    await tester.pumpAndSettle();
    final bounds = tester.getRect(learningChart);
    await tester.tapAt(Offset(bounds.left + 90, bounds.bottom - 50));
    await tester.pumpAndSettle();
    final selectedLearning = tooltip('learning-tooltip');
    expect(selectedLearning, contains('Sep 1 – Sep 6'));
    expect(selectedLearning, contains('cards'));
    expect(selectedLearning, contains('net'));
    expect(selectedLearning, isNot(contains('recalls')));
    expect(tooltip('recall-tooltip'), originalRecall);
    final recallChart = find.byKey(const ValueKey('activity-chart'));
    await tester.ensureVisible(recallChart);
    await tester.pumpAndSettle();
    final recallBounds = tester.getRect(recallChart);
    await tester.tapAt(
      Offset(recallBounds.left + 90, recallBounds.bottom - 50),
    );
    await tester.pumpAndSettle();
    expect(tooltip('recall-tooltip'), contains('Sep 1 – Sep 6'));
    expect(tooltip('recall-tooltip'), contains('recalls'));
    expect(tooltip('recall-tooltip'), isNot(contains('net')));
    expect(tooltip('learning-tooltip'), selectedLearning);
    expect(find.byTooltip('Previous day'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('real progress provider times out and recovers with retry', (
    tester,
  ) async {
    var ready = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeCardsSessionProvider.overrideWith(
            (_) async => const CachedSession(
              serverId: 'test',
              userId: 'user',
              domainId: 1,
              application: 'nx_cards',
              route: 'test',
            ),
          ),
          localCardsStoreProvider.overrideWithValue(null),
          cardsCollectionProvider.overrideWith(
            (_, _) => ready
                ? Stream.value(CardsDashboard(cards: demoCards))
                : const Stream.empty(),
          ),
          cardsInvalidationProvider.overrideWith(
            (ref) =>
                () => ref.invalidate(cardsCollectionProvider),
          ),
        ],
        child: MaterialApp(
          theme: buildRecallTheme(),
          home: const ProgressPage(language: 'Chinese'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 21));
    await tester.pumpAndSettle();
    expect(find.textContaining('Loading cards took too long'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    expect(find.textContaining('Loading cards took too long'), findsOneWidget);
    ready = true;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Learning progress'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'category entry overrides remembered scope and restores other filters',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'progress.v2.server.user.4.Chinese':
            '{"target":90,"direction":"from_language","period":"7","category":"Word","path":["Word"]}',
      });
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeCardsSessionProvider.overrideWith(
              (_) async => const CachedSession(
                serverId: 'server',
                userId: 'user',
                domainId: 4,
                application: 'nx_cards',
                route: 'test',
              ),
            ),
            progressCardsProvider.overrideWith((_, _) async => demoCards),
          ],
          child: MaterialApp(
            theme: buildRecallTheme(),
            home: Scaffold(
              appBar: AppBar(
                actions: const [
                  ProgressAction(
                    language: 'Chinese',
                    group: LanguageGroup('Basics', path: ['Script', 'Basics']),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open-progress')));
      await tester.pumpAndSettle();
      expect(find.text('Chinese · Progress'), findsOneWidget);
      expect(find.text('Script › Basics'), findsOneWidget);
      expect(find.text('At least 90%'), findsOneWidget);
      expect(find.text('Recall type'), findsNothing);
      expect(find.text('Last 7 days'), findsOneWidget);

      expect(tester.takeException(), isNull);
    },
  );
}
