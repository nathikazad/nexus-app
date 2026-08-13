import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/composition/cards_composition.dart';
import 'package:nx_cards/domain/card/cards_repository.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/features/study/language_fast_recall_page.dart';

void main() {
  testWidgets('grades rows inline, reveals answers, and opens card details', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final card = _card();
    final repository = _RecordingCardsRepository();
    final dashboard = CardsDashboard(cards: [card]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardsRepositoryProvider.overrideWithValue(repository),
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
    await tester.pump();

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
      await tester.pump();
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
  });

  testWidgets('a rated row quickly collapses after the answer was revealed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final card = _card();
    final secondCard = _card(id: 2);
    final repository = _RecordingCardsRepository();
    final dashboard = CardsDashboard(cards: [card, secondCard]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardsRepositoryProvider.overrideWithValue(repository),
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
    final row = find.byKey(const ValueKey<String>('fast-row-1'));
    await tester.tap(find.byKey(const ValueKey<String>('fast-hidden-1')));
    await tester.pump();
    expect(find.text('ആശ്വാസം'), findsOneWidget);
    final revealedHeight = tester.getSize(row).height;
    await tester.tap(find.byTooltip('Recalled'));
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
    final repository = _RecordingCardsRepository();
    final dashboard = CardsDashboard(cards: [first, second]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardsRepositoryProvider.overrideWithValue(repository),
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
      tester.getCenter(find.byKey(const ValueKey<String>('fast-row-1'))),
    );
    await firstGesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await firstGesture.moveBy(const Offset(100, 0));
    await tester.pump();
    expect(find.text('ആശ്വാസം'), findsWidgets);
    await firstGesture.up();
    await tester.pump(const Duration(milliseconds: 699));
    expect(repository.saved, isEmpty);
    await tester.pump(const Duration(milliseconds: 2));
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
      tester.getCenter(find.byKey(const ValueKey<String>('fast-row-2'))),
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
}

final class _RecordingCardsRepository implements CardsRepository {
  final List<StudyCard> saved = <StudyCard>[];

  @override
  Future<void> saveSchedule(StudyCard card) async => saved.add(card);

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
  learningStatus: LearningStatus.learning,
);
