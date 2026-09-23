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
      schedules: {},
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
    'moves a card between all placements and keeps failed saves unchanged',
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
      SegmentedButton<LearningStatus> selector() =>
          tester.widget(find.byKey(const ValueKey('card-learning-status')));
      expect(selector().selected, {LearningStatus.notStarted});
      for (final entry in {
        'Active': LearningStatus.learning,
        'Inactive': LearningStatus.notStarted,
      }.entries) {
        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();
        expect(selector().selected, {entry.value});
        expect(library.savedStatus, entry.value);
        expect(library.savedCard?.id, 20);
      }
      library.pending = Completer<void>();
      await tester.tap(find.text('Active'));
      await tester.pump();
      expect(selector().onSelectionChanged, isNull);
      expect(selector().selected, {LearningStatus.notStarted});
      library.pending!.completeError(StateError('Save failed'));
      await tester.pumpAndSettle();
      expect(selector().selected, {LearningStatus.notStarted});
      expect(selector().onSelectionChanged, isNotNull);
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
    expect(find.text('Examples (1)'), findsOneWidget);
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

  testWidgets('only offers recall directions with collected history', (
    tester,
  ) async {
    final reviewedAt = DateTime.now().toUtc().subtract(const Duration(days: 2));
    final card = _card(
      schedules: {
        StudyCue.fromLanguage: _schedule(reviewedAt, reviewCount: 2),
        StudyCue.toLanguage: _schedule(reviewedAt, reviewCount: 1),
        StudyCue.transliteration: const CardSchedule.initial(enabled: true),
      },
      reviewHistory: {
        StudyCue.fromLanguage: [
          _review('from-1', reviewedAt, rating: 1),
          _review('from-2', reviewedAt.add(const Duration(days: 1)), rating: 3),
        ],
        StudyCue.toLanguage: [_review('to-1', reviewedAt, rating: 3)],
        StudyCue.transliteration: const [],
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
    expect(find.text('Front → Malayalam'), findsOneWidget);
    expect(find.text('1 yes · 1 no'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('2 reviews'), findsOneWidget);
    expect(find.byKey(const ValueKey('review-history-graph')), findsOneWidget);
  });

  testWidgets('does not show navigation for a single reviewed direction', (
    tester,
  ) async {
    final reviewedAt = DateTime.now().toUtc().subtract(const Duration(days: 1));
    final card = _card(
      schedules: {
        StudyCue.fromLanguage: _schedule(reviewedAt, reviewCount: 1),
        StudyCue.toLanguage: const CardSchedule.initial(enabled: true),
        StudyCue.transliteration: const CardSchedule.initial(enabled: true),
      },
      reviewHistory: {
        StudyCue.fromLanguage: [_review('one', reviewedAt, rating: 3)],
        StudyCue.toLanguage: const [],
        StudyCue.transliteration: const [],
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

    expect(
      find.byKey(const ValueKey('single-review-direction')),
      findsOneWidget,
    );
    expect(find.text('Front → Malayalam'), findsOneWidget);
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
        StudyCue.fromLanguage: CardSchedule(
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
        StudyCue.toLanguage: const CardSchedule.initial(enabled: true),
        StudyCue.transliteration: const CardSchedule.initial(enabled: true),
      },
      reviewHistory: {
        StudyCue.fromLanguage: [
          _review('failed-1', now.subtract(const Duration(days: 3)), rating: 1),
          _review('failed-2', now.subtract(const Duration(days: 2)), rating: 1),
          _review('failed-3', now.subtract(const Duration(days: 1)), rating: 2),
          _review('failed-4', now, rating: 1),
        ],
        StudyCue.toLanguage: const [],
        StudyCue.transliteration: const [],
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

    expect(find.text('Future'), findsOneWidget);
    expect(find.text('Learning step 2 of 2'), findsNothing);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('0 of last 10 recalled'), findsOneWidget);
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
        StudyCue.fromLanguage: CardSchedule.initial(enabled: true),
        StudyCue.toLanguage: CardSchedule.initial(enabled: true),
        StudyCue.transliteration: CardSchedule.initial(enabled: true),
      },
  reviewHistory:
      reviewHistory ??
      const <StudyCue, List<CardReview>>{
        StudyCue.fromLanguage: <CardReview>[],
        StudyCue.toLanguage: <CardReview>[],
        StudyCue.transliteration: <CardReview>[],
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
  Completer<void>? pending;

  @override
  Future<void> setLearningStatus(StudyCard card, LearningStatus status) async {
    if (pending case final operation?) await operation.future;
    savedCard = card;
    savedStatus = status;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
