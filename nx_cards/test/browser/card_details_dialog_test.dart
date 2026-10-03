import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/audio/audio_providers.dart';
import 'package:nx_cards/app/theme.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/browser/card_details_page.dart';

void main() {
  testWidgets(
    'unreviewed skill selection shows empty history without losing controls',
    (tester) async {
      final card = _card(
        schedules: {
          for (final cue in StudyCue.languageDirections)
            cue: const CardSchedule.initial(enabled: true),
        },
        reviewHistory: {
          StudyCue.meaningToSound: [
            _review('sound', DateTime.now(), rating: 3),
          ],
        },
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [cardAudioRepositoryProvider.overrideWithValue(null)],
          child: MaterialApp(
            home: CardDetailsPage(card: card, initialTab: CardDetailsTab.stats),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final skill in ['meaning', 'sound']) {
        final chip = find.byKey(ValueKey('direction-$skill'));
        await Scrollable.ensureVisible(tester.element(chip), alignment: .4);
        await tester.pumpAndSettle();
        await tester.tap(chip);
        await tester.pumpAndSettle();
      }
      expect(
        tester
            .widget<FilterChip>(find.byKey(const ValueKey('direction-meaning')))
            .selected,
        isFalse,
      );
      expect(
        tester
            .widget<FilterChip>(find.byKey(const ValueKey('direction-sound')))
            .selected,
        isFalse,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('No reviews for these skills yet.'), findsOneWidget);
      expect(find.text('Average of 1 skill'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final spokenOnly in [false, true]) {
    testWidgets(
      'stats chips union histories and adapt to spokenOnly=$spokenOnly',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final time = DateTime.now().subtract(const Duration(days: 1));
        final card =
            _card(
              schedules: {
                for (final cue in StudyCue.languageDirections)
                  cue: const CardSchedule.initial(enabled: true),
              },
              reviewHistory: {
                for (final cue in StudyCue.languageDirections)
                  cue: [
                    _review(
                      cue.storageKey,
                      time,
                      rating: cue == StudyCue.scriptToSound ? 1 : 3,
                    ),
                  ],
              },
            ).copyWith(
              content: LanguageCardContent(
                english: 'cat',
                originalScript: '猫',
                transliteration: 'māo',
                spokenOnly: spokenOnly,
              ),
            );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [cardAudioRepositoryProvider.overrideWithValue(null)],
            child: MaterialApp(
              theme: buildRecallTheme(),
              home: CardDetailsPage(
                card: card,
                initialTab: CardDetailsTab.stats,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Finder chip(String name) => find.byKey(ValueKey('direction-$name'));
        expect(tester.widget<FilterChip>(chip('meaning')).selected, isTrue);
        expect(tester.widget<FilterChip>(chip('sound')).selected, isTrue);
        expect(chip('script'), spokenOnly ? findsNothing : findsOneWidget);
        expect(
          find.descendant(
            of: chip('meaning'),
            matching: find.text(spokenOnly ? '40%' : '80%'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: chip('sound'),
            matching: find.text(spokenOnly ? '40%' : '60%'),
          ),
          findsOneWidget,
        );
        expect(
          find.text(spokenOnly ? 'Average of 2 skills' : 'Average of 3 skills'),
          findsOneWidget,
        );
        await tester.ensureVisible(chip('sound'));
        await tester.tap(chip('sound'));
        await tester.pumpAndSettle();
        // Two selected skills still cover all six directions, without duplication.
        expect(
          find.text(spokenOnly ? 'Average of 1 skill' : 'Average of 2 skills'),
          findsOneWidget,
        );
        if (!spokenOnly) {
          await tester.tap(chip('script'));
          await tester.pumpAndSettle();
          expect(find.text('Average of 1 skill'), findsOneWidget);
          expect(find.text('4 yes · 0 no'), findsOneWidget);
        }
        await tester.drag(find.byType(ListView), const Offset(0, 1000));
        await tester.pumpAndSettle();
        await tester.ensureVisible(chip('meaning'));
        await tester.tap(chip('meaning'));
        await tester.pumpAndSettle();
        expect(tester.widget<FilterChip>(chip('meaning')).selected, isTrue);
        await tester.drag(find.byType(ListView), const Offset(0, -700));
        await tester.pumpAndSettle();
        expect(
          find.text(spokenOnly ? '2 reviews' : '4 reviews'),
          findsOneWidget,
        );
        await tester.binding.setSurfaceSize(const Size(820, 1000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Spoken only is below Active, saves and retains value after a failed save',
    (tester) async {
      final library = _StatusLibrary();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cardAudioRepositoryProvider.overrideWithValue(null),
            cardLibraryProvider.overrideWithValue(library),
            cardsInvalidationProvider.overrideWithValue(() {}),
          ],
          child: MaterialApp(home: CardDetailsPage(card: _card())),
        ),
      );
      await tester.pumpAndSettle();
      final toggle = find.byKey(const ValueKey('card-spoken-only'));
      SwitchListTile selector() => tester.widget(toggle);
      expect(selector().value, false);
      expect(
        tester.getTopLeft(toggle).dy,
        greaterThanOrEqualTo(
          tester
              .getBottomLeft(find.byKey(const ValueKey('card-learning-status')))
              .dy,
        ),
      );
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(selector().value, true);
      expect(library.savedSpokenOnly, true);
      expect(library.savedStatus, _card().learningStatus);
      library.pending = Completer<void>();
      await tester.tap(toggle);
      await tester.pump();
      expect(selector().onChanged, isNull);
      library.pending!.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(selector().value, true);
      expect(
        find.textContaining('Could not update spoken only'),
        findsOneWidget,
      );
      library.pending = null;
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(selector().value, false);
      expect(library.savedSpokenOnly, false);
    },
  );

  testWidgets('Similar shows every group with no category suffix', (
    tester,
  ) async {
    final base = _card().copyWith(learningStatus: LearningStatus.recall);
    final card = base.copyWith(
      content: (base.content as LanguageCardContent).copyWith(
        similarWordGroups: ['one-sound', 'two-other'],
      ),
    );
    final peer = StudyCard(
      id: 200,
      learningStatus: LearningStatus.recall,
      tags: base.tags,
      suspended: false,
      schedules: {
        for (final direction in StudyCue.values)
          direction: CardSchedule.initial(
            enabled: direction != StudyCue.backToFront,
          ),
      },
      reviewHistory: const {},
      content: (base.content as LanguageCardContent).copyWith(
        english: 'peer meaning',
        similarWordGroups: ['one-sound'],
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardsCollectionProvider.overrideWith(
            (ref, source) => Stream.value(CardsDashboard(cards: [card, peer])),
          ),
        ],
        child: MaterialApp(home: CardDetailsPage(card: card)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Similar'));
    await tester.tap(find.text('Similar'));
    await tester.pumpAndSettle();
    expect(find.text('one'), findsOneWidget);
    expect(find.text('two'), findsOneWidget);
    expect(find.text('peer meaning'), findsOneWidget);
    expect(find.text('one-sound'), findsNothing);
    expect(find.byType(ExpansionTile), findsNothing);
  });

  testWidgets('saved word example opens by id and contains links back', (
    tester,
  ) async {
    StudyCard make(
      int id,
      String text, {
      Set<int> contains = const {},
      List<LanguageExample> examples = const [],
    }) => StudyCard(
      id: id,
      modelTypeName: 'Word',
      content: LanguageCardContent(
        english: text,
        originalScript: text,
        transliteration: text,
        examples: examples,
      ),
      schedules: {
        for (final direction in StudyCue.values)
          direction: CardSchedule.initial(
            enabled: direction != StudyCue.backToFront,
          ),
      },
      reviewHistory: {},
      suspended: false,
      linkedWordIds: contains,
    );
    final character = make(
      1,
      '午',
      examples: [
        const LanguageExample(
          cardId: 2,
          text: '下午',
          transliteration: 'xiàwǔ',
          translation: 'afternoon',
        ),
      ],
    );
    // Different display text demonstrates that navigation uses the saved ID.
    final word = make(2, '下午 updated', contains: {1});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardsDashboardProvider.overrideWith(
            (_) => Stream.value(CardsDashboard(cards: [character, word])),
          ),
        ],
        child: MaterialApp(home: CardDetailsPage(card: character)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('下午'));
    await tester.pumpAndSettle();
    expect(find.text('CONTAINS'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, '午'));
    await tester.pumpAndSettle();
    expect(find.text('EXAMPLES'), findsOneWidget);
    expect(find.text('下午'), findsOneWidget);
  });

  testWidgets(
    'Active switch moves between Current and Backlog and preserves failed saves',
    (tester) async {
      final library = _StatusLibrary();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cardAudioRepositoryProvider.overrideWithValue(null),
            cardLibraryProvider.overrideWithValue(library),
            cardsDashboardProvider.overrideWith(
              (_) => Stream.value(const CardsDashboard(cards: [])),
            ),
          ],
          child: MaterialApp(
            home: CardDetailsPage(card: _card(), allowEdit: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      SwitchListTile selector() =>
          tester.widget(find.byKey(const ValueKey('card-learning-status')));
      expect(selector().value, false);
      final content = find.byKey(const ValueKey('card-content'));
      final contentWidth = tester.getSize(content).width;
      for (final entry in {
        'Current': LearningStatus.recall,
        'Backlog': LearningStatus.future,
      }.entries) {
        await tester.tap(find.byKey(const ValueKey('card-learning-status')));
        await tester.pumpAndSettle();
        expect(selector().value, entry.value == LearningStatus.recall);
        expect(library.savedStatus, entry.value);
        expect(library.savedCard?.id, 20);
        expect(tester.getSize(content).width, contentWidth);
        if (entry.value == LearningStatus.recall) {
          expect(
            tester
                .getBottomRight(
                  find.byKey(const ValueKey('card-detail-recall-strength')),
                )
                .dy,
            lessThan(tester.getTopLeft(content).dy),
          );
        }
        expect(
          find.byKey(const ValueKey('card-detail-recall-strength')),
          entry.value == LearningStatus.recall ? findsOneWidget : findsNothing,
        );
      }
      library.pending = Completer<void>();
      await tester.tap(find.byKey(const ValueKey('card-learning-status')));
      await tester.pump();
      expect(selector().onChanged, isNull);
      expect(selector().value, false);
      library.pending!.completeError(StateError('Save failed'));
      await tester.pumpAndSettle();
      expect(selector().value, false);
      expect(selector().onChanged, isNotNull);
      expect(find.textContaining('Could not move card'), findsOneWidget);
    },
  );

  testWidgets('phrase shows notes and linked vocabulary', (tester) async {
    final word = _card();
    final phrase = StudyCard(
      id: 500,
      modelTypeName: 'Phrase',
      notes: 'Learn this expression as a whole.',
      content: const LanguageCardContent(
        english: 'A phrase',
        originalScript: 'ഒരു തട്ടിപ്പ്',
        transliteration: 'oru thattippu',
      ),
      schedules: word.schedules,
      reviewHistory: word.reviewHistory,
      suspended: false,
      linkedWordIds: {word.id},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardsDashboardProvider.overrideWith(
            (_) => Stream.value(CardsDashboard(cards: [word, phrase])),
          ),
        ],
        child: MaterialApp(home: CardDetailsPage(card: phrase)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('CONTAINS'), findsOneWidget);
    expect(find.textContaining('thattippu — fraud'), findsOneWidget);
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(find.text('Learn this expression as a whole.'), findsOneWidget);
    await tester.ensureVisible(find.text('തട്ടിപ്പ്'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('തട്ടിപ്പ്'));
    await tester.pumpAndSettle();
    expect(find.text('fraud'), findsOneWidget);
  });

  testWidgets('tapping example text opens its phrase details', (tester) async {
    final word = _card();
    final example = (word.content as LanguageCardContent).examples.single;
    final phrase = StudyCard(
      id: 501,
      modelTypeName: 'Phrase',
      content: LanguageCardContent(
        english: example.translation,
        originalScript: example.text,
        transliteration: example.transliteration,
      ),
      schedules: word.schedules,
      reviewHistory: word.reviewHistory,
      suspended: false,
      linkedWordIds: {word.id},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardsDashboardProvider.overrideWith(
            (_) => Stream.value(CardsDashboard(cards: [word, phrase])),
          ),
        ],
        child: MaterialApp(home: CardDetailsPage(card: word)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(example.text));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('CONTAINS'), findsOneWidget);
    expect(find.text(example.translation), findsOneWidget);
  });

  testWidgets('shows examples inline and hides empty stats navigation', (
    tester,
  ) async {
    final card = _card();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [cardAudioRepositoryProvider.overrideWithValue(null)],
        child: MaterialApp(home: CardDetailsPage(card: card)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Card details'), findsOneWidget);
    expect(find.text('fraud'), findsOneWidget);
    expect(find.text('തട്ടിപ്പ്'), findsOneWidget);
    expect(find.text('thattippu'), findsOneWidget);
    expect(find.text('Examples (1)'), findsNothing);
    expect(find.byType(SegmentedButton<CardDetailsTab>), findsNothing);
    expect(find.text('അത് ഒരു തട്ടിപ്പായിരുന്നു.'), findsOneWidget);
    expect(find.text('Stats'), findsNothing);
    expect(
      find.byKey(const ValueKey('review-direction-selector')),
      findsNothing,
    );
  });

  testWidgets('card content uses a readable dark surface', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [cardAudioRepositoryProvider.overrideWithValue(null)],
        child: MaterialApp(
          theme: buildRecallTheme(),
          darkTheme: buildRecallDarkTheme(),
          themeMode: ThemeMode.dark,
          home: CardDetailsPage(card: _card()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final content = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('card-content')),
    );
    final decoration = content.decoration as BoxDecoration;
    expect(decoration.color, const Color(0xff18181b));
    expect(decoration.color, isNot(const Color(0xfff4f4f5)));
  });

  testWidgets(
    'stats includes all skills and preserves existing review history',
    (tester) async {
      final reviewedAt = DateTime.now().toUtc().subtract(
        const Duration(days: 2),
      );
      final card = _card(
        schedules: {
          for (final direction in StudyCue.values)
            direction: CardSchedule.initial(
              enabled: direction != StudyCue.backToFront,
            ),
          StudyCue.meaningToScript: _schedule(reviewedAt, reviewCount: 2),
          StudyCue.scriptToMeaning: _schedule(reviewedAt, reviewCount: 1),
          StudyCue.scriptToSound: const CardSchedule.initial(enabled: true),
        },
        reviewHistory: {
          StudyCue.meaningToScript: [
            _review('from-1', reviewedAt, rating: 1),
            _review(
              'from-2',
              reviewedAt.add(const Duration(days: 1)),
              rating: 3,
            ),
          ],
          StudyCue.scriptToMeaning: [_review('to-1', reviewedAt, rating: 3)],
          StudyCue.scriptToSound: const [],
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [cardAudioRepositoryProvider.overrideWithValue(null)],
          child: MaterialApp(home: CardDetailsPage(card: card)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Stats'), findsOneWidget);
      expect(find.text('Examples (1)'), findsOneWidget);
      expect(find.text('അത് ഒരു തട്ടിപ്പായിരുന്നു.'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Examples (1)')).dx,
        lessThan(tester.getTopLeft(find.text('Stats')).dx),
      );
      await tester.ensureVisible(find.text('Stats'));
      await tester.tap(find.text('Stats'));
      await tester.pumpAndSettle();
      expect(find.text('അത് ഒരു തട്ടിപ്പായിരുന്നു.'), findsNothing);
      expect(
        find.byKey(const ValueKey('review-direction-selector')),
        findsNothing,
      );
      expect(find.text('Meaning'), findsOneWidget);
      expect(find.text('2 yes · 1 no'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(find.text('3 reviews'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('review-history-graph')),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows all skill chips even with a single reviewed direction', (
    tester,
  ) async {
    final reviewedAt = DateTime.now().toUtc().subtract(const Duration(days: 1));
    final card = _card(
      schedules: {
        for (final direction in StudyCue.values)
          direction: CardSchedule.initial(
            enabled: direction != StudyCue.backToFront,
          ),
        StudyCue.meaningToScript: _schedule(reviewedAt, reviewCount: 1),
        StudyCue.scriptToMeaning: const CardSchedule.initial(enabled: true),
        StudyCue.scriptToSound: const CardSchedule.initial(enabled: true),
      },
      reviewHistory: {
        StudyCue.meaningToScript: [_review('one', reviewedAt, rating: 3)],
        StudyCue.scriptToMeaning: const [],
        StudyCue.scriptToSound: const [],
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [cardAudioRepositoryProvider.overrideWithValue(null)],
        child: MaterialApp(
          home: CardDetailsPage(card: card, initialTab: CardDetailsTab.stats),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('stats-components')), findsOneWidget);
    expect(find.text('Meaning'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('review-direction-selector')),
      findsNothing,
    );
  });

  testWidgets('learning cards show observed recall instead of an estimate', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    final card = _card(
      schedules: {
        for (final direction in StudyCue.values)
          direction: CardSchedule.initial(
            enabled: direction != StudyCue.backToFront,
          ),
        StudyCue.meaningToScript: CardSchedule(
          enabled: true,
          dueAt: now.add(const Duration(minutes: 10)),
          lastReviewedAt: now,
          stability: 1.5,
          difficulty: 6,
          schedulingState: 'learning',
          learningStep: 1,
          reviewCount: 4,
          lapseCount: 0,
        ),
        StudyCue.scriptToMeaning: const CardSchedule.initial(enabled: true),
        StudyCue.scriptToSound: const CardSchedule.initial(enabled: true),
      },
      reviewHistory: {
        StudyCue.meaningToScript: [
          _review('failed-1', now.subtract(const Duration(days: 3)), rating: 1),
          _review('failed-2', now.subtract(const Duration(days: 2)), rating: 1),
          _review('failed-3', now.subtract(const Duration(days: 1)), rating: 2),
          _review('failed-4', now, rating: 1),
        ],
        StudyCue.scriptToMeaning: const [],
        StudyCue.scriptToSound: const [],
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [cardAudioRepositoryProvider.overrideWithValue(null)],
        child: MaterialApp(
          home: CardDetailsPage(card: card, initialTab: CardDetailsTab.stats),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('Backlog'), findsOneWidget);
    expect(find.text('Learning step 2 of 2'), findsNothing);
    expect(find.text('0%'), findsNWidgets(4));
    expect(find.text('Average of 3 skills'), findsOneWidget);
    expect(find.text('estimated recall'), findsNothing);
  });
}

StudyCard _card({
  Map<StudyCue, CardSchedule>? schedules,
  Map<StudyCue, List<CardReview>>? reviewHistory,
}) => StudyCard(
  id: 20,
  content: const LanguageCardContent(
    english: 'fraud',
    originalScript: 'തട്ടിപ്പ്',
    transliteration: 'thattippu',
    examples: <LanguageExample>[
      LanguageExample(
        text: 'അത് ഒരു തട്ടിപ്പായിരുന്നു.',
        transliteration: 'athu oru thattippayirunnu',
        translation: 'It was a fraud.',
      ),
    ],
  ),
  schedules:
      schedules ??
      const <StudyCue, CardSchedule>{
        StudyCue.meaningToScript: CardSchedule.initial(enabled: true),
        StudyCue.scriptToMeaning: CardSchedule.initial(enabled: true),
        StudyCue.scriptToSound: CardSchedule.initial(enabled: true),
      },
  reviewHistory:
      reviewHistory ??
      const <StudyCue, List<CardReview>>{
        StudyCue.meaningToScript: <CardReview>[],
        StudyCue.scriptToMeaning: <CardReview>[],
        StudyCue.scriptToSound: <CardReview>[],
      },
  tags: const <String, List<String>>{
    'Language': ['Malayalam'],
  },
  suspended: false,
);

CardSchedule _schedule(DateTime reviewedAt, {required int reviewCount}) =>
    CardSchedule(
      enabled: true,
      dueAt: reviewedAt.add(const Duration(days: 4)),
      lastReviewedAt: reviewedAt,
      stability: 4,
      difficulty: 5,
      schedulingState: 'review',
      learningStep: null,
      reviewCount: reviewCount,
      lapseCount: 1,
    );

CardReview _review(String id, DateTime reviewedAt, {required int rating}) =>
    CardReview(
      id: id,
      reviewedAt: reviewedAt,
      rating: rating,
      elapsedSeconds: const Duration(days: 2).inSeconds,
      scheduledSeconds: const Duration(days: 4).inSeconds,
    );

final class _StatusLibrary implements CardLibrary {
  StudyCard? savedCard;
  LearningStatus? savedStatus;
  bool? savedSpokenOnly;
  Completer<void>? pending;

  @override
  Future<void> setLearningStatus(
    StudyCard card,
    LearningStatus status, {
    bool? spokenOnly,
  }) async {
    if (pending case final operation?) await operation.future;
    savedSpokenOnly = spokenOnly;
    savedCard = card;
    savedStatus = status;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
