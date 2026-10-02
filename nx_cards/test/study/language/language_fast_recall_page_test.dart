import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/audio/audio_providers.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/study/language/language_fast_recall_page.dart';

void main() {
  testWidgets(
    'the same word can be graded in three directions without losing earlier history',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final card = _card().copyWith(
        schedules: {
          for (final cue in StudyCue.activeDirections)
            cue: const CardSchedule.initial(enabled: true),
        },
      );
      final repository = _RecordingCardLibrary();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cardAudioRepositoryProvider.overrideWithValue(null),
            cardLibraryProvider.overrideWithValue(repository),
            cardsDashboardProvider.overrideWith(
              (_) => Stream.value(CardsDashboard(cards: [card])),
            ),
          ],
          child: MaterialApp(
            home: LanguageFastRecallPage(
              title: 'Mixed recall',
              prompts: [
                for (final cue in StudyCue.activeDirections)
                  StudyPrompt(card: card, cue: cue),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final cue in StudyCue.activeDirections) {
        final row = find.byKey(ValueKey('fast-row-1-${cue.storageKey}'));
        final reveal = find.descendant(
          of: row,
          matching: find.byKey(const ValueKey('fast-hidden-1')),
        );
        await tester.ensureVisible(reveal);
        await tester.tap(reveal);
        await tester.pumpAndSettle();
        final yes = find.descendant(
          of: row,
          matching: find.byTooltip('Recalled'),
        );
        await tester.ensureVisible(yes);
        await tester.tap(yes);
        await tester.pumpAndSettle();
      }
      expect(repository.saved, hasLength(3));
      expect(
        repository.saved.last.reviewHistoryFor(StudyCue.fromLanguage),
        hasLength(2),
      );
      expect(
        repository.saved.last.reviewHistoryFor(StudyCue.fromAudio),
        hasLength(1),
      );
      expect(
        repository.saved.last.reviewHistoryFor(StudyCue.toLanguage),
        hasLength(1),
      );
      expect(find.text('3 of 3 cards reviewed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 390.0, 760.0]) {
    testWidgets('listening row keeps playback beside the prompt at $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final card = _card();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cardAudioRepositoryProvider.overrideWithValue(_LayoutAudio()),
            cardsDashboardProvider.overrideWith(
              (_) => Stream.value(CardsDashboard(cards: [card])),
            ),
          ],
          child: MaterialApp(
            home: LanguageFastRecallPage(
              title: 'Chinese',
              prompts: [StudyPrompt(card: card, cue: StudyCue.fromAudio)],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Listen'), findsOneWidget);
      expect(find.text('relief'), findsNothing);
      final prompt = tester.getRect(
        find.byKey(const ValueKey('fast-prompt-1')),
      );
      final play = tester.getRect(find.byTooltip('Play pronunciation'));
      expect(play.left - prompt.right, inInclusiveRange(0, 12));
      expect((play.center.dy - prompt.center.dy).abs(), lessThan(5));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('fast-hidden-1')));
      await tester.pumpAndSettle();
      expect(find.text('relief'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 31));
    });
  }
  testWidgets('grades rows inline, reveals answers, and opens card details', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final card = _card();
    final repository = _RecordingCardLibrary();
    final dashboard = CardsDashboard(cards: [card]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardLibraryProvider.overrideWithValue(repository),
          cardsDashboardProvider.overrideWith((_) => Stream.value(dashboard)),
        ],
        child: MaterialApp(
          home: LanguageFastRecallPage(
            title: 'Malayalam nouns',
            prompts: [StudyPrompt(card: card, cue: StudyCue.fromLanguage)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('relief'), findsOneWidget);
    expect(find.text('Tap to reveal'), findsOneWidget);
    expect(find.text('ആശ്വാസം'), findsNothing);
    expect(find.byTooltip('Did not recall'), findsNothing);
    expect(find.byTooltip('Recalled'), findsNothing);
    expect(find.byTooltip('Play pronunciation'), findsNothing);
    expect(find.text('Examples'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('fast-hidden-1')));
    await tester.pumpAndSettle();

    expect(find.text('ആശ്വാസം'), findsOneWidget);
    expect(find.text('āśvāsaṃ'), findsOneWidget);
    expect(find.byTooltip('Did not recall'), findsOneWidget);
    expect(find.byTooltip('Recalled'), findsOneWidget);
    expect(
      tester.getCenter(find.byTooltip('Recalled')).dx,
      lessThan(tester.getCenter(find.byTooltip('Did not recall')).dx),
    );

    await tester.tap(find.byKey(const ValueKey<String>('fast-answer-1')));
    await tester.pumpAndSettle();
    expect(find.text('Card details'), findsOneWidget);
    expect(find.text('Stats'), findsOneWidget);
    expect(find.text('Examples (1)'), findsOneWidget);
    expect(find.text('ഉദാഹരണം'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    if (find.byTooltip('Did not recall').evaluate().isEmpty) {
      await tester.tap(find.byKey(const ValueKey<String>('fast-hidden-1')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byTooltip('Did not recall'));
    await tester.pumpAndSettle();

    expect(repository.saved, hasLength(1));
    expect(
      repository.saved.single.scheduleFor(StudyCue.fromLanguage).reviewCount,
      1,
    );
    expect(find.text('Session complete'), findsOneWidget);
    expect(find.text('1 of 1 cards reviewed'), findsOneWidget);
    expect(find.text('INCORRECT'), findsOneWidget);
    expect(find.text('relief'), findsOneWidget);
    expect(find.text('ആശ്വാസം'), findsOneWidget);
    expect(find.text('āśvāsaṃ'), findsOneWidget);
    await tester.tap(find.byTooltip('Retry missed and untried cards').first);
    await tester.pumpAndSettle();
    expect(find.text('Session complete'), findsNothing);
    expect(find.text('Tap to reveal'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('fast-hidden-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Recalled'));
    await tester.pumpAndSettle();
    expect(repository.saved, hasLength(2));
    expect(
      repository.saved.last.scheduleFor(StudyCue.fromLanguage).reviewCount,
      2,
    );
    expect(find.text('CORRECT'), findsOneWidget);
    expect(find.text('Repeat'), findsNothing);
    expect(find.text('Return'), findsNWidgets(2));
  });

  testWidgets('a rated row quickly collapses after the answer was revealed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final card = _card();
    final secondCard = _card(id: 2);
    final repository = _RecordingCardLibrary();
    final dashboard = CardsDashboard(cards: [card, secondCard]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardLibraryProvider.overrideWithValue(repository),
          cardsDashboardProvider.overrideWith((_) => Stream.value(dashboard)),
        ],
        child: MaterialApp(
          home: LanguageFastRecallPage(
            title: 'Malayalam nouns',
            prompts: [
              StudyPrompt(card: card, cue: StudyCue.fromLanguage),
              StudyPrompt(card: secondCard, cue: StudyCue.fromLanguage),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey<String>('fast-row-1-from_language'));
    await tester.tap(find.byKey(const ValueKey<String>('fast-hidden-1')));
    await tester.pumpAndSettle();
    expect(find.text('ആശ്വാസം'), findsOneWidget);
    final revealedHeight = tester.getSize(row).height;
    await tester.tap(find.byTooltip('Recalled'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.getSize(row).height, lessThan(revealedHeight));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.getSize(row).height, 0);
  });

  testWidgets('one swipe reveals and grades right as yes and left as no', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final first = _card();
    final second = _card(id: 2);
    final repository = _RecordingCardLibrary();
    final dashboard = CardsDashboard(cards: [first, second]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardLibraryProvider.overrideWithValue(repository),
          cardsDashboardProvider.overrideWith((_) => Stream.value(dashboard)),
        ],
        child: MaterialApp(
          home: LanguageFastRecallPage(
            title: 'Malayalam nouns',
            prompts: [
              StudyPrompt(card: first, cue: StudyCue.fromLanguage),
              StudyPrompt(card: second, cue: StudyCue.fromLanguage),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstGesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey<String>('fast-row-1-from_language')),
      ),
    );
    await firstGesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await firstGesture.moveBy(const Offset(100, 0));
    await tester.pump();
    expect(find.text('ആശ്വാസം'), findsWidgets);
    await firstGesture.up();
    await tester.pumpAndSettle();
    expect(repository.saved, hasLength(1));
    expect(
      repository.saved.first
          .reviewHistoryFor(StudyCue.fromLanguage)
          .last
          .rating,
      3,
    );

    final secondGesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey<String>('fast-row-2-from_language')),
      ),
    );
    await secondGesture.moveBy(const Offset(-40, 0));
    await tester.pump();
    await secondGesture.moveBy(const Offset(-100, 0));
    await tester.pump();
    await secondGesture.up();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(repository.saved, hasLength(2));
    expect(
      repository.saved.last.reviewHistoryFor(StudyCue.fromLanguage).last.rating,
      1,
    );
  });

  testWidgets('swipe hides immediately and restores after a save timeout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final first = _card();
    final second = _card(id: 2);
    final saveGate = Completer<void>();
    final repository = _RecordingCardLibrary(saveGate: saveGate);
    final dashboard = CardsDashboard(cards: [first, second]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardLibraryProvider.overrideWithValue(repository),
          cardsDashboardProvider.overrideWith((_) => Stream.value(dashboard)),
        ],
        child: MaterialApp(
          home: LanguageFastRecallPage(
            title: 'Malayalam nouns',
            prompts: [
              StudyPrompt(card: first, cue: StudyCue.fromLanguage),
              StudyPrompt(card: second, cue: StudyCue.fromLanguage),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final row = find.byKey(const ValueKey<String>('fast-row-1-from_language'));
    final gesture = await tester.startGesture(tester.getCenter(row));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(100, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(tester.getSize(row).height, 0);
    expect(repository.saved, isEmpty);

    await tester.pump(const Duration(seconds: 21));
    await tester.pumpAndSettle();

    expect(tester.getSize(row).height, greaterThan(0));
    expect(
      find.text('Could not save the review. The card was restored.'),
      findsOneWidget,
    );
    saveGate.complete();
    await tester.pump();
  });
}

final class _RecordingCardLibrary implements CardLibrary {
  _RecordingCardLibrary({this.saveGate});

  final List<StudyCard> saved = <StudyCard>[];
  final Completer<void>? saveGate;

  @override
  Future<void> saveSchedule(StudyCard card) async {
    await saveGate?.future;
    saved.add(card);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

StudyCard _card({int id = 1}) => StudyCard(
  id: id,
  content: const LanguageCardContent(
    english: 'relief',
    originalScript: 'ആശ്വാസം',
    transliteration: 'āśvāsaṃ',
    audioUrl: '/audio/1.mp3',
    examples: [
      LanguageExample(
        text: 'ഉദാഹരണം',
        transliteration: 'udāharaṇaṃ',
        translation: 'example',
      ),
    ],
  ),
  schedules: const <StudyCue, CardSchedule>{
    StudyCue.fromLanguage: CardSchedule.initial(enabled: true),
  },
  reviewHistory: <StudyCue, List<CardReview>>{
    StudyCue.fromLanguage: <CardReview>[
      CardReview(
        id: 'existing-review',
        reviewedAt: DateTime.utc(2026, 8, 1),
        rating: 3,
        elapsedSeconds: 86400,
        scheduledSeconds: 172800,
      ),
    ],
  },
  suspended: false,
  learningStatus: LearningStatus.recall,
);

class _LayoutAudio implements CardAudioRepository {
  @override
  Future<Uint8List> fetch(String url) async =>
      throw StateError('No native audio in layout test');
}
