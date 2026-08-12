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
    final dashboard = CardsDashboard(decks: const [_deck], cards: [card]);

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

    await tester.tap(find.text('Tap to reveal'));
    await tester.pump();

    expect(find.text('ആശ്വാസം'), findsOneWidget);
    expect(find.text('āśvāsaṃ'), findsOneWidget);
    expect(find.byTooltip('Did not recall'), findsOneWidget);
    expect(find.byTooltip('Recalled'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('fast-answer-1')));
    await tester.pumpAndSettle();
    expect(find.text('Card details'), findsOneWidget);
    expect(find.text('Stats'), findsOneWidget);
    expect(find.text('Examples (1)'), findsOneWidget);
    expect(find.text('ഉദാഹരണം'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Did not recall'));
    await tester.pumpAndSettle();

    expect(repository.saved, hasLength(1));
    expect(
      repository.saved.single.scheduleFor(StudyCue.fromLanguage).reviewCount,
      1,
    );
    expect(find.text('1 of 1 recalled'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('fast-row-1'))).height,
      0,
    );
  });

  testWidgets('a rated row quickly collapses after the answer was revealed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final card = _card();
    final repository = _RecordingCardsRepository();
    final dashboard = CardsDashboard(decks: const [_deck], cards: [card]);

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
    final row = find.byKey(const ValueKey<String>('fast-row-1'));
    await tester.tap(find.text('Tap to reveal'));
    await tester.pump();
    expect(find.text('ആശ്വാസം'), findsOneWidget);
    final revealedHeight = tester.getSize(row).height;
    await tester.tap(find.byTooltip('Recalled'));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.getSize(row).height, lessThan(revealedHeight));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.getSize(row).height, 0);
  });
}

final class _RecordingCardsRepository implements CardsRepository {
  final List<StudyCard> saved = <StudyCard>[];

  @override
  Future<void> saveSchedule(StudyCard card) async => saved.add(card);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _deck = CardDeck(
  id: 7,
  name: 'Malayalam nouns',
  description: '',
  fromLanguage: 'English',
  toLanguage: 'Malayalam',
  archived: false,
);

StudyCard _card() => StudyCard(
  id: 1,
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
  deckId: 7,
  deckName: 'Malayalam nouns',
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
