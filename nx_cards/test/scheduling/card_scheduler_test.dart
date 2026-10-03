import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/scheduling/card_scheduler.dart';

void main() {
  test('audio grades have independent history, strength and schedule', () {
    final card = StudyCard(
      id: 7,
      reviewHistory: const {},
      suspended: false,
      learningStatus: LearningStatus.recall,
      content: const LanguageCardContent(
        english: 'student',
        originalScript: '学生',
        transliteration: 'xuésheng',
        audioUrl: '/student.mp3',
      ),
      schedules: {
        for (final direction in StudyCue.values)
          direction: CardSchedule.initial(
            enabled: direction != StudyCue.backToFront,
          ),
        StudyCue.soundToMeaning: CardSchedule.initial(enabled: true),
        StudyCue.scriptToMeaning: CardSchedule.initial(enabled: true),
      },
    );
    final scheduler = FsrsCardScheduler(reviewId: () => 'audio-review');
    final prompt = StudyPrompt(card: card, cue: StudyCue.soundToMeaning);
    expect(prompt.withCard(card).prompt, 'Listen');
    expect(prompt.schedule.enabled, isTrue);
    final graded = scheduler
        .preview(prompt, DateTime.utc(2026, 9, 28))[CardRating.good]!
        .card;
    expect(
      graded.reviewHistoryFor(StudyCue.soundToMeaning).single.id,
      'audio-review',
    );
    expect(graded.scheduleFor(StudyCue.soundToMeaning).reviewCount, 1);
    expect(
      graded.scheduleFor(StudyCue.scriptToMeaning),
      same(card.scheduleFor(StudyCue.scriptToMeaning)),
    );
    expect(graded.reviewHistoryFor(StudyCue.scriptToMeaning), isEmpty);
    expect(graded.reviewHistoryFor(StudyCue.meaningToScript), isEmpty);
  });

  test('FSRS preview returns a persistable outcome for every rating', () {
    final now = DateTime.utc(2026, 8, 3, 12);
    final card = StudyCard(
      id: 42,
      content: const BasicCardContent(front: 'bonjour', back: 'hello'),
      schedules: {
        for (final direction in StudyCue.values)
          direction: CardSchedule.initial(
            enabled: direction != StudyCue.backToFront,
          ),
        StudyCue.frontToBack: CardSchedule.initial(enabled: true),
        StudyCue.backToFront: CardSchedule.initial(enabled: false),
        StudyCue.scriptToSound: CardSchedule.initial(enabled: false),
      },
      reviewHistory: const <StudyCue, List<CardReview>>{
        StudyCue.frontToBack: <CardReview>[],
        StudyCue.backToFront: <CardReview>[],
        StudyCue.scriptToSound: <CardReview>[],
      },
      suspended: false,
    );
    final prompt = StudyPrompt(card: card, cue: StudyCue.frontToBack);

    final outcomes = FsrsCardScheduler(
      reviewId: () => 'review-id',
    ).preview(prompt, now);

    expect(outcomes.keys, containsAll(CardRating.values));
    for (final outcome in outcomes.values) {
      final schedule = outcome.card.scheduleFor(StudyCue.frontToBack);
      final history = outcome.card.reviewHistoryFor(StudyCue.frontToBack);
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
        outcome.card.scheduleFor(StudyCue.backToFront),
        same(card.scheduleFor(StudyCue.backToFront)),
      );
    }
  });

  test('Again increments lapse count for an already reviewed card', () {
    final now = DateTime.utc(2026, 8, 3, 12);
    final card = StudyCard(
      id: 42,
      content: const BasicCardContent(front: 'bonjour', back: 'hello'),
      schedules: {
        for (final direction in StudyCue.values)
          direction: CardSchedule.initial(
            enabled: direction != StudyCue.backToFront,
          ),
        StudyCue.frontToBack: CardSchedule(
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
        StudyCue.backToFront: const CardSchedule.initial(enabled: false),
        StudyCue.scriptToSound: const CardSchedule.initial(enabled: false),
      },
      reviewHistory: const <StudyCue, List<CardReview>>{
        StudyCue.frontToBack: <CardReview>[],
        StudyCue.backToFront: <CardReview>[],
        StudyCue.scriptToSound: <CardReview>[],
      },
      suspended: false,
    );

    final outcome = FsrsCardScheduler(reviewId: () => 'review-id').preview(
      StudyPrompt(card: card, cue: StudyCue.frontToBack),
      now,
    )[CardRating.again]!;

    final schedule = outcome.card.scheduleFor(StudyCue.frontToBack);
    final history = outcome.card.reviewHistoryFor(StudyCue.frontToBack);
    expect(schedule.lapseCount, 2);
    expect(schedule.schedulingState, 'relearning');
    expect(history.single.rating, 1);
    expect(history.single.elapsedSeconds, const Duration(days: 3).inSeconds);
  });
}
