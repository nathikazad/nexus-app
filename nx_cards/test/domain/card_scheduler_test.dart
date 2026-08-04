import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/domain/scheduling/card_scheduler.dart';

void main() {
  test('FSRS preview returns a persistable outcome for every rating', () {
    final now = DateTime.utc(2026, 8, 3, 12);
    final card = StudyCard(
      id: 42,
      front: 'bonjour',
      back: 'hello',
      deckId: 1,
      deckName: 'French',
      tags: const ['Vocabulary'],
      dueAt: null,
      lastReviewedAt: null,
      stability: null,
      difficulty: null,
      schedulingState: 'learning',
      learningStep: 0,
      suspended: false,
      reviewCount: 0,
      lapseCount: 0,
    );

    final outcomes = FsrsCardScheduler(
      reviewId: () => 'review-id',
    ).preview(card, now);

    expect(outcomes.keys, containsAll(CardRating.values));
    for (final outcome in outcomes.values) {
      expect(outcome.card.lastReviewedAt, now);
      expect(outcome.card.dueAt, isNotNull);
      expect(outcome.card.reviewCount, 1);
      expect(outcome.card.stability, isNotNull);
      expect(outcome.card.difficulty, isNotNull);
      expect(outcome.card.reviewHistory, hasLength(1));
      expect(outcome.card.reviewHistory.single.id, 'review-id');
      expect(outcome.card.reviewHistory.single.reviewedAt, now);
      expect(outcome.card.reviewHistory.single.rating, inInclusiveRange(1, 4));
      expect(outcome.card.reviewHistory.single.elapsedSeconds, 0);
      expect(
        outcome.card.reviewHistory.single.scheduledSeconds,
        greaterThan(0),
      );
    }
  });

  test('Again increments lapse count for an already reviewed card', () {
    final now = DateTime.utc(2026, 8, 3, 12);
    final card = StudyCard(
      id: 42,
      front: 'bonjour',
      back: 'hello',
      deckId: 1,
      deckName: 'French',
      tags: const [],
      dueAt: now,
      lastReviewedAt: now.subtract(const Duration(days: 3)),
      stability: 3,
      difficulty: 5,
      schedulingState: 'review',
      learningStep: null,
      suspended: false,
      reviewCount: 4,
      lapseCount: 1,
    );

    final outcome = FsrsCardScheduler(
      reviewId: () => 'review-id',
    ).preview(card, now)[CardRating.again]!;

    expect(outcome.card.lapseCount, 2);
    expect(outcome.card.schedulingState, 'relearning');
    expect(outcome.card.reviewHistory.single.rating, 1);
    expect(
      outcome.card.reviewHistory.single.elapsedSeconds,
      const Duration(days: 3).inSeconds,
    );
  });
}
