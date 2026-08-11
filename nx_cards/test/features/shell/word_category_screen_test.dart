import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/composition/cards_composition.dart';
import 'package:nx_cards/domain/card/cards_repository.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/features/shell/cards_home.dart';

void main() {
  testWidgets('shows front-to-back state and one due marker on current words', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    final current = _word(
      id: 1,
      learningStatus: LearningStatus.learning,
      schedule: _schedule(now.subtract(const Duration(minutes: 2))),
    );
    final available = _word(
      id: 2,
      learningStatus: LearningStatus.notStarted,
      schedule: _schedule(now.subtract(const Duration(minutes: 2))),
    );
    final learnt = _word(
      id: 3,
      learningStatus: LearningStatus.learnt,
      schedule: _schedule(now.subtract(const Duration(minutes: 2))),
    );
    final dashboard = CardsDashboard(
      decks: const [_deck],
      cards: [current, available, learnt],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardsDashboardProvider.overrideWith((_) => Stream.value(dashboard)),
        ],
        child: const MaterialApp(home: WordCategoryScreen(category: 'Noun')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LEARNING'), findsOneWidget);
    expect(find.text('DUE'), findsOneWidget);
    expect(find.byKey(const ValueKey('word-schedule-due')), findsOneWidget);
    expect(find.text('Learning  1'), findsOneWidget);
    expect(find.text('Learnt  1'), findsOneWidget);
    expect(find.text('Not started  1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('right swipe moves learning and learnt words back one status', (
    tester,
  ) async {
    final repository = _RecordingCardsRepository();
    final now = DateTime.now().toUtc();
    final learning = _word(
      id: 1,
      learningStatus: LearningStatus.learning,
      schedule: _schedule(now),
    );
    final learnt = _word(
      id: 3,
      learningStatus: LearningStatus.learnt,
      schedule: _schedule(now),
    );
    final dashboard = CardsDashboard(
      decks: const [_deck],
      cards: [learning, learnt],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardAudioRepositoryProvider.overrideWithValue(null),
          cardsRepositoryProvider.overrideWithValue(repository),
          cardsDashboardProvider.overrideWith((_) => Stream.value(dashboard)),
        ],
        child: const MaterialApp(home: WordCategoryScreen(category: 'Noun')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('learning:1')),
      const Offset(100, 0),
    );
    await tester.pumpAndSettle();
    expect(repository.changes.last, (1, LearningStatus.notStarted));

    await tester.tap(find.text('Learnt  1'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('learnt:3')),
      const Offset(100, 0),
    );
    await tester.pumpAndSettle();
    expect(repository.changes.last, (3, LearningStatus.learning));
  });
}

final class _RecordingCardsRepository implements CardsRepository {
  final changes = <(int, LearningStatus)>[];

  @override
  Future<void> setLearningStatus(StudyCard card, LearningStatus status) async {
    changes.add((card.id, status));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _deck = CardDeck(
  id: 10,
  name: 'Malayalam nouns',
  description: '',
  fromLanguage: 'English',
  toLanguage: 'Malayalam',
  archived: false,
);

StudyCard _word({
  required int id,
  required LearningStatus learningStatus,
  required CardSchedule schedule,
}) => StudyCard(
  id: id,
  content: LanguageCardContent(
    english: id == 1 ? 'worry' : 'responsibility',
    originalScript: id == 1 ? 'ആശങ്ക' : 'ഉത്തരവാദിത്വം',
    transliteration: id == 1 ? 'aashanka' : 'utharavaadithvam',
  ),
  deckId: _deck.id,
  deckName: _deck.name,
  schedules: {
    StudyCue.fromLanguage: schedule,
    StudyCue.toLanguage: const CardSchedule.initial(enabled: true),
    StudyCue.transliteration: const CardSchedule.initial(enabled: true),
  },
  reviewHistory: const {},
  suspended: false,
  learningStatus: learningStatus,
  tags: const {
    'Word Category': ['Noun'],
  },
  modelTypeName: 'Word',
);

CardSchedule _schedule(DateTime dueAt) => CardSchedule(
  enabled: true,
  dueAt: dueAt,
  lastReviewedAt: dueAt.subtract(const Duration(days: 1)),
  stability: 1,
  difficulty: 5,
  schedulingState: 'learning',
  learningStep: 0,
  reviewCount: 1,
  lapseCount: 0,
);
