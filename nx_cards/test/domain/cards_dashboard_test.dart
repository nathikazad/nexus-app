import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/domain/cards_models.dart';

void main() {
  final now = DateTime.utc(2026, 8, 3, 12);
  const deck = CardDeck(
    id: 1,
    name: 'French',
    description: '',
    language: 'French',
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

    expect(queue.map((card) => card.id), [1, 2]);
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
}

StudyCard _card(
  int id, {
  DateTime? dueAt,
  DateTime? reviewed,
  bool suspended = false,
}) {
  return StudyCard(
    id: id,
    front: 'front $id',
    back: 'back $id',
    deckId: 1,
    deckName: 'French',
    tags: const [],
    dueAt: dueAt,
    lastReviewedAt: reviewed,
    stability: reviewed == null ? null : 1,
    difficulty: reviewed == null ? null : 5,
    schedulingState: reviewed == null ? 'learning' : 'review',
    learningStep: reviewed == null ? 0 : null,
    suspended: suspended,
    reviewCount: reviewed == null ? 0 : 1,
    lapseCount: 0,
  );
}
