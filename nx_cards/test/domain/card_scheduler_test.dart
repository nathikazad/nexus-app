import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/domain/scheduling/card_scheduler.dart';

void main() {
  test('FSRS preview returns a persistable outcome for every rating', () {
    final now = DateTime.utc(2026, 8, 3, 12);
    final card = StudyCard(
      id: 42,
      content: const BasicCardContent(front: 'bonjour', back: 'hello'),
      deckId: 1,
      deckName: 'French',
      schedules: const <StudyCue, CardSchedule>{
        StudyCue.fromLanguage: CardSchedule.initial(enabled: true),
        StudyCue.toLanguage: CardSchedule.initial(enabled: false),
        StudyCue.transliteration: CardSchedule.initial(enabled: false),
      },
      reviewHistory: const <StudyCue, List<CardReview>>{
        StudyCue.fromLanguage: <CardReview>[],
        StudyCue.toLanguage: <CardReview>[],
        StudyCue.transliteration: <CardReview>[],
      },
      suspended: false,
    );
    final prompt = StudyPrompt(card: card, cue: StudyCue.fromLanguage);

    final outcomes = FsrsCardScheduler(
      reviewId: () => 'review-id',
    ).preview(prompt, now);

    expect(outcomes.keys, containsAll(CardRating.values));
    for (final outcome in outcomes.values) {
      final schedule = outcome.card.scheduleFor(StudyCue.fromLanguage);
      final history = outcome.card.reviewHistoryFor(StudyCue.fromLanguage);
      expect(schedule.lastReviewedAt, now);
      expect(schedule.dueAt, isNotNull);
      expect(schedule.reviewCount, 1);
      expect(schedule.stability, isNotNull);
      expect(schedule.difficulty, isNotNull);
      expect(history, hasLength(1));
      expect(history.single.id, 'review-id');
      expect(history.single.reviewedAt, now);
      expect(history.single.rating, inInclusiveRange(1, 4));
      expect(history.single.elapsedSeconds, 0);
      expect(history.single.scheduledSeconds, greaterThan(0));
      expect(
        outcome.card.scheduleFor(StudyCue.toLanguage),
        same(card.scheduleFor(StudyCue.toLanguage)),
      );
    }
  });

  test('Again increments lapse count for an already reviewed card', () {
    final now = DateTime.utc(2026, 8, 3, 12);
    final card = StudyCard(
      id: 42,
      content: const BasicCardContent(front: 'bonjour', back: 'hello'),
      deckId: 1,
      deckName: 'French',
      schedules: <StudyCue, CardSchedule>{
        StudyCue.fromLanguage: CardSchedule(
          enabled: true,
          dueAt: now,
          lastReviewedAt: now.subtract(const Duration(days: 3)),
          stability: 3,
          difficulty: 5,
          schedulingState: 'review',
          learningStep: null,
          reviewCount: 4,
          lapseCount: 1,
        ),
        StudyCue.toLanguage: const CardSchedule.initial(enabled: false),
        StudyCue.transliteration: const CardSchedule.initial(enabled: false),
      },
      reviewHistory: const <StudyCue, List<CardReview>>{
        StudyCue.fromLanguage: <CardReview>[],
        StudyCue.toLanguage: <CardReview>[],
        StudyCue.transliteration: <CardReview>[],
      },
      suspended: false,
    );

    final outcome = FsrsCardScheduler(reviewId: () => 'review-id').preview(
      StudyPrompt(card: card, cue: StudyCue.fromLanguage),
      now,
    )[CardRating.again]!;

    final schedule = outcome.card.scheduleFor(StudyCue.fromLanguage);
    final history = outcome.card.reviewHistoryFor(StudyCue.fromLanguage);
    expect(schedule.lapseCount, 2);
    expect(schedule.schedulingState, 'relearning');
    expect(history.single.rating, 1);
    expect(history.single.elapsedSeconds, const Duration(days: 3).inSeconds);
  });
}
