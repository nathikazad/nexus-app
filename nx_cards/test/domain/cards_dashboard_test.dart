import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/domain/cards_models.dart';

void main() {
  final now = DateTime.utc(2026, 8, 3, 12);
  const deck = CardDeck(
    id: 1,
    name: 'French',
    description: '',
    fromLanguage: 'English',
    toLanguage: 'French',
    archived: false,
  );

  test('study queue places due cards before limited new cards', () {
    final dashboard = CardsDashboard(
      decks: const [deck],
      cards: [
        _card(1, dueAt: now.subtract(const Duration(days: 1)), reviewed: now),
        _card(2),
        _card(3),
        _card(4, dueAt: now.add(const Duration(days: 1)), reviewed: now),
      ],
    );

    final queue = dashboard.studyQueue(now, newCardLimit: 1);

    expect(queue.map((prompt) => prompt.cardId), [1, 2]);
    expect(dashboard.dueCount(now), 1);
    expect(dashboard.newCount(), 2);
  });

  test('suspended cards never enter the queue', () {
    final dashboard = CardsDashboard(
      decks: const [deck],
      cards: [_card(1, suspended: true)],
    );

    expect(dashboard.studyQueue(now), isEmpty);
  });

  test('each enabled cue has independent queue eligibility', () {
    final dashboard = CardsDashboard(
      decks: const [deck],
      cards: [_card(1, enableAllCues: true)],
    );

    final queue = dashboard.studyQueue(now);

    expect(queue, hasLength(3));
    expect(queue.map((prompt) => prompt.cue), StudyCue.values);
    expect(dashboard.newCount(), 1);
    expect(dashboard.cardCount(1), 1);
  });

  test('new language cues are mixed without adjacent siblings', () {
    final dashboard = CardsDashboard(
      decks: const [deck],
      cards: [
        _card(1, enableAllCues: true),
        _card(2, enableAllCues: true),
        _card(3, enableAllCues: true),
      ],
    );

    final queue = dashboard.studyQueue(now);

    expect(queue, hasLength(9));
    for (var index = 1; index < queue.length; index++) {
      expect(queue[index].cardId, isNot(queue[index - 1].cardId));
    }
    expect(queue.map((prompt) => prompt.cue).toSet(), StudyCue.values.toSet());
  });
}

StudyCard _card(
  int id, {
  DateTime? dueAt,
  DateTime? reviewed,
  bool suspended = false,
  bool enableAllCues = false,
}) {
  return StudyCard(
    id: id,
    content: LanguageCardContent(
      english: 'front $id',
      originalScript: 'back $id',
      transliteration: 'sound $id',
    ),
    deckId: 1,
    deckName: 'French',
    schedules: <StudyCue, CardSchedule>{
      StudyCue.fromLanguage: CardSchedule(
        enabled: true,
        dueAt: dueAt,
        lastReviewedAt: reviewed,
        stability: reviewed == null ? null : 1,
        difficulty: reviewed == null ? null : 5,
        schedulingState: reviewed == null ? 'learning' : 'review',
        learningStep: reviewed == null ? 0 : null,
        reviewCount: reviewed == null ? 0 : 1,
        lapseCount: 0,
      ),
      StudyCue.toLanguage: CardSchedule.initial(enabled: enableAllCues),
      StudyCue.transliteration: CardSchedule.initial(enabled: enableAllCues),
    },
    reviewHistory: const <StudyCue, List<CardReview>>{
      StudyCue.fromLanguage: <CardReview>[],
      StudyCue.toLanguage: <CardReview>[],
      StudyCue.transliteration: <CardReview>[],
    },
    suspended: suspended,
  );
}
