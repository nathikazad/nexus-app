import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/audio/audio_providers.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/browser/card_list/study_launcher.dart';
import 'package:nx_cards/browser/language/language_page.dart';

StudyCard card(
  int id, {
  String language = 'Tamil',
  String type = 'Word',
  Map<String, List<String>> tags = const {},
  LearningStatus status = LearningStatus.learning,
}) => StudyCard(
  id: id,
  modelTypeName: type,
  content: LanguageCardContent(
    english: 'item $id',
    originalScript: 'சொல் $id',
    transliteration: 'sol $id',
  ),
  schedules: {
    for (final cue in StudyCue.values)
      cue: const CardSchedule.initial(enabled: true),
  },
  reviewHistory: const {},
  suspended: false,
  learningStatus: status,
  tags: {
    'Language': [language],
    ...tags,
  },
);

Future<void> showPage(WidgetTester tester, List<StudyCard> cards) async {
  await tester.binding.setSurfaceSize(const Size(1200, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cardsCollectionProvider.overrideWith(
          (_, _) => Stream.value(CardsDashboard(cards: cards)),
        ),
        cardAudioRepositoryProvider.overrideWithValue(null),
      ],
      child: const MaterialApp(home: LanguagePage(language: 'Tamil')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('database tags appear automatically with name-based icons', (
    tester,
  ) async {
    await showPage(tester, [
      card(
        1,
        tags: {
          'Word Category': ['Adjective'],
        },
      ),
      card(
        2,
        type: 'Phrase',
        tags: {
          'Collection': ['Family Conversations 1'],
        },
      ),
      card(
        3,
        type: 'Phrase',
        tags: {
          'Collection': ['Husband Conversations 1'],
        },
      ),
      card(
        4,
        tags: {
          'My new tag system': ['Travel'],
        },
      ),
      card(
        5,
        language: 'Chinese',
        tags: {
          'Collection': ['Other language only'],
        },
      ),
    ]);
    for (final name in [
      'Adjective',
      'Phrase',
      'Family Conversations 1',
      'Husband Conversations 1',
      'Travel',
    ]) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('Other language only'), findsNothing);
    expect(find.text('Tamil'), findsOneWidget); // Page title, no language tile.
    expect(find.byIcon(Icons.tune_outlined), findsOneWidget);
    final family = find.ancestor(
      of: find.text('Family Conversations 1'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(
        of: family,
        matching: find.byIcon(Icons.text_fields_outlined),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tag navigation and study use only matching card IDs', (
    tester,
  ) async {
    await showPage(tester, [
      card(
        1,
        tags: {
          'Collection': ['Travel', 'Family'],
        },
      ),
      card(
        2,
        tags: {
          'Collection': ['Travel'],
        },
        status: LearningStatus.notStarted,
      ),
      card(
        3,
        tags: {
          'Collection': ['Family'],
        },
      ),
      card(
        4,
        tags: {
          'Topic': ['Travel'],
        },
      ),
      card(
        5,
        language: 'Chinese',
        tags: {
          'Collection': ['Travel'],
        },
      ),
    ]);
    await tester.tap(find.text('Travel (Collection)'));
    await tester.pumpAndSettle();
    expect(find.text('2 cards · 1 learning'), findsOneWidget);
    expect(find.text('item 1'), findsOneWidget);
    expect(find.text('item 3'), findsNothing);
    expect(find.text('item 4'), findsNothing);
    final launcher = tester.widget<StudyLauncher>(find.byType(StudyLauncher));
    expect(launcher.studyCards.map((c) => c.id), [1]);
    expect(launcher.prompts.map((p) => p.cardId).toSet(), {1});
    await tester.tap(find.text('Future  1'));
    await tester.pumpAndSettle();
    expect(find.text('item 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'phrase collections retain membership in the general Phrase group',
    (tester) async {
      await showPage(tester, [
        card(
          1,
          type: 'Phrase',
          tags: {
            'Collection': ['Family Conversations 1', 'Husband Conversations 1'],
          },
        ),
        card(
          2,
          type: 'Phrase',
          tags: {
            'Collection': ['Family Conversations 1'],
          },
        ),
        card(3, type: 'Phrase'),
      ]);
      await tester.tap(find.text('Husband Conversations 1'));
      await tester.pumpAndSettle();
      expect(find.text('1 cards · 1 learning'), findsOneWidget);
      expect(
        tester
            .widget<StudyLauncher>(find.byType(StudyLauncher))
            .studyCards
            .map((c) => c.id),
        [1],
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Phrase'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<StudyLauncher>(find.byType(StudyLauncher))
            .studyCards
            .map((c) => c.id)
            .toSet(),
        {1, 2, 3},
      );
      expect(tester.takeException(), isNull);
    },
  );
}
