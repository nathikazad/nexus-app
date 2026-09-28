import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/scheduling/card_scheduler.dart';

void main() {
  test(
    'Written and Listening update the same reverse history and schedule',
    () {
      final card = StudyCard(
        id: 7,
        reviewHistory: const {},
        content: const LanguageCardContent(
          english: 'student',
          originalScript: '学生',
          transliteration: 'xuésheng',
        ),
        schedules: const {
          StudyCue.toLanguage: CardSchedule.initial(enabled: true),
        },
        suspended: false,
      );
      final written = StudyPrompt(card: card, cue: StudyCue.toLanguage);
      final listening = StudyPrompt(
        card: card,
        cue: StudyCue.toLanguage,
        listening: true,
      );
      expect(written.prompt, '学生');
      expect(listening.withCard(card).prompt, 'Listen');
      expect(listening.cue, written.cue);
      final scheduler = FsrsCardScheduler(reviewId: () => 'same-review');
      final now = DateTime.utc(2026, 9, 27);
      final a = scheduler.preview(written, now)[CardRating.good]!.card;
      final b = scheduler.preview(listening, now)[CardRating.good]!.card;
      expect(
        a.scheduleFor(StudyCue.toLanguage).dueAt,
        b.scheduleFor(StudyCue.toLanguage).dueAt,
      );
      expect(
        a.scheduleFor(StudyCue.toLanguage).stability,
        b.scheduleFor(StudyCue.toLanguage).stability,
      );
      expect(b.reviewHistoryFor(StudyCue.toLanguage).single.id, 'same-review');
      expect(b.reviewHistoryFor(StudyCue.fromLanguage), isEmpty);
      expect(b.reviewHistoryFor(StudyCue.transliteration), isEmpty);
    },
  );

  test('FSRS preview returns a persistable outcome for every rating', () {
    final now = DateTime.utc(2026, 8, 3, 12);
    final card = StudyCard(
      id: 42,
      content: const BasicCardContent(front: 'bonjour', back: 'hello'),
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
