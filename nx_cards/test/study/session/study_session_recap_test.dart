import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/audio/audio_providers.dart';
import 'package:nx_cards/app/theme.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/study/session/study_session_page.dart';
import 'package:nx_cards/study/session/recall_recap_page.dart';

void main() {
  test('retry preserves prompt conditions and includes untried cards', () {
    final card = StudyCard(
      id: 1,
      content: const LanguageCardContent(
        english: 'house',
        originalScript: 'வீடு',
        transliteration: 'vīṭu',
      ),
      schedules: const {},
      reviewHistory: const {},
      suspended: false,
    );
    final latest = card.copyWith(learningStatus: LearningStatus.recall);
    final prompts = [
      StudyPrompt(card: card, cue: StudyCue.toLanguage),
      StudyPrompt(
        card: card,
        cue: StudyCue.fromLanguage,
        showEnglishAndTransliteration: true,
      ),
      StudyPrompt(card: card, cue: StudyCue.transliteration),
      StudyPrompt(card: card, cue: StudyCue.fromLanguage),
    ];
    final repeated = retryRecallPrompts(
      prompts,
      {0: CardRating.good, 1: CardRating.again, 2: CardRating.hard},
      {1: latest},
    );
    expect(repeated, hasLength(2));
    expect(repeated.every((p) => identical(p.card, latest)), isTrue);
    expect(repeated.every((p) => p.cue == StudyCue.fromLanguage), isTrue);
    expect(repeated.last.showEnglishAndTransliteration, isTrue);
    expect(repeated.last.prompt, 'house\nvīṭu');
    expect(repeated.first.showEnglishAndTransliteration, isFalse);
  });

  testWidgets('partial ten-card round shows 3 recalled, 2 missed, 5 untried', (
    tester,
  ) async {
    var retried = false;
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: RecallRecapPage(
            reviewedCount: 5,
            totalCount: 10,
            missCount: 2,
            entries: const [],
            onRepeatIncorrect: () => retried = true,
          ),
        ),
      ),
    );
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Not tried'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Retry missed and untried cards'));
    expect(retried, isTrue);
  });

  test(
    'retry mixes two misses and five untried cards without changing history',
    () {
      final prompts = List.generate(
        10,
        (i) => StudyPrompt(
          card: StudyCard(
            id: i,
            content: BasicCardContent(front: '$i', back: '$i'),
            schedules: const {},
            reviewHistory: const {},
            suspended: false,
          ),
          cue: StudyCue.fromAudio,
        ),
      );
      final ratings = {
        0: CardRating.good,
        1: CardRating.again,
        2: CardRating.good,
        3: CardRating.again,
        4: CardRating.good,
      };
      final retry = retryRecallPrompts(prompts, ratings, {});
      expect(
        retry.map((p) => p.cardId),
        unorderedEquals([1, 3, 5, 6, 7, 8, 9]),
      );
      expect(retry.map((p) => p.cardId).toList(), isNot([1, 3, 5, 6, 7, 8, 9]));
      expect(
        retry.every(
          (p) => p.cue == StudyCue.fromAudio && p.reviewHistory.isEmpty,
        ),
        isTrue,
      );
      expect(
        retryRecallPrompts(prompts.take(1).toList(), {0: CardRating.good}, {}),
        isEmpty,
      );
    },
  );

  testWidgets('recall completion recaps every word in all three forms', (
    tester,
  ) async {
    final card = StudyCard(
      id: 1,
      content: const LanguageCardContent(
        english: 'talent',
        originalScript: 'കഴിവ്',
        transliteration: 'kazhivu',
      ),
      schedules: const {
        StudyCue.fromLanguage: CardSchedule.initial(enabled: true),
      },
      reviewHistory: const {},
      suspended: false,
      learningStatus: LearningStatus.recall,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardsDashboardProvider.overrideWith(
            (_) => Stream.value(const CardsDashboard(cards: [])),
          ),
        ],
        child: MaterialApp(
          home: StudySessionPage(
            title: 'Malayalam',
            prompts: [StudyPrompt(card: card, cue: StudyCue.fromLanguage)],
          ),
        ),
      ),
    );
    await tester.tap(find.text('End'));
    await tester.pumpAndSettle();

    expect(find.text('WORDS'), findsOneWidget);
    expect(find.text('talent'), findsOneWidget);
    expect(find.text('കഴിവ്'), findsOneWidget);
    expect(find.text('kazhivu'), findsOneWidget);
    expect(find.text('NOT REVIEWED'), findsOneWidget);
    expect(find.text('Not tried'), findsOneWidget);
    await tester.tap(find.byTooltip('Retry missed and untried cards'));
    await tester.pumpAndSettle();
    expect(find.text('WORDS'), findsNothing);
    expect(find.text('Show answer'), findsOneWidget);
  });

  testWidgets('recall recap uses a readable dark surface', (tester) async {
    final card = StudyCard(
      id: 1,
      content: const LanguageCardContent(
        english: 'talent',
        originalScript: 'കഴിവ്',
        transliteration: 'kazhivu',
      ),
      schedules: const {
        StudyCue.fromLanguage: CardSchedule.initial(enabled: true),
      },
      reviewHistory: const {},
      suspended: false,
      learningStatus: LearningStatus.recall,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardsDashboardProvider.overrideWith(
            (_) => Stream.value(const CardsDashboard(cards: [])),
          ),
        ],
        child: MaterialApp(
          theme: buildRecallTheme(),
          darkTheme: buildRecallDarkTheme(),
          themeMode: ThemeMode.dark,
          home: StudySessionPage(
            title: 'Malayalam',
            prompts: [StudyPrompt(card: card, cue: StudyCue.fromLanguage)],
          ),
        ),
      ),
    );
    await tester.tap(find.text('End'));
    await tester.pumpAndSettle();

    final recap = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('recall-word-recap')),
    );
    final decoration = recap.decoration as BoxDecoration;
    expect(decoration.color, const Color(0xff18181b));
    expect(decoration.color, isNot(const Color(0xfff4f4f5)));
  });
}
