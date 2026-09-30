import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/scheduling/learning_stage.dart';

StudyCard card(List<int> ratings, {bool active = true}) => StudyCard(
  id: 1,
  content: const LanguageCardContent(
    english: 'learn',
    originalScript: '学',
    transliteration: 'xué',
  ),
  suspended: false,
  learningStatus: active ? LearningStatus.recall : LearningStatus.future,
  schedules: {
    for (final cue in StudyCue.values)
      cue: const CardSchedule.initial(enabled: true),
  },
  reviewHistory: {
    StudyCue.fromLanguage: [
      for (final (i, rating) in ratings.indexed)
        CardReview(
          id: 'r$i',
          reviewedAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
          rating: rating,
          elapsedSeconds: 0,
          scheduledSeconds: 0,
        ),
    ],
  },
);
void main() {
  test(
    'activation shared, zero attempts distinct from failure, directions independent',
    () {
      expect(
        learningStage(card([]), StudyCue.fromLanguage),
        LearningStage.current,
      );
      expect(
        learningStage(card([1]), StudyCue.fromLanguage),
        LearningStage.current,
      );
      expect(
        learningStage(card([3]), StudyCue.toLanguage),
        LearningStage.current,
      );
      expect(
        learningStage(
          card(List.filled(10, 3), active: false),
          StudyCue.fromLanguage,
        ),
        LearningStage.future,
      );
    },
  );
  test('score denominator grows from five to ten, then rolls over', () {
    for (var attempts = 0; attempts <= 12; attempts++) {
      final score = recallScore(
        card(List.filled(attempts, 3)),
        StudyCue.fromLanguage,
      );
      expect(score.attempts, attempts.clamp(0, 10));
      expect(score.denominator, attempts.clamp(5, 10));
      expect(score.percentage, attempts < 5 ? attempts * 20 : 100);
    }
    final mixed = recallScore(card([3, 3, 3, 1, 1]), StudyCue.fromLanguage);
    expect(mixed.percentage, 60);
    expect(
      recallScore(card([3, 3, 3, 3, 3, 1]), StudyCue.fromLanguage).percentage,
      83,
    );
    expect(
      recallScore(
        card([...List.filled(10, 3), ...List.filled(10, 1)]),
        StudyCue.fromLanguage,
      ).percentage,
      0,
    );
    expect(
      recallScore(
        card([...List.filled(10, 1), ...List.filled(8, 3), 1, 1]),
        StudyCue.fromLanguage,
      ).percentage,
      80,
    );
    expect(
      learningStage(card([3, 3, 3, 3]), StudyCue.fromLanguage),
      LearningStage.past,
    );
    expect(
      learningStage(card([3, 3, 3, 3, 1, 1]), StudyCue.fromLanguage),
      LearningStage.current,
    );
  });
  test('score deduplicates reviews and keeps directions separate', () {
    final original = card([3]);
    final duplicate = original.copyWith(
      reviewHistory: {
        StudyCue.fromLanguage: [
          original.reviewHistoryFor(StudyCue.fromLanguage).single,
          original.reviewHistoryFor(StudyCue.fromLanguage).single,
        ],
        StudyCue.fromAudio: card(
          List.filled(10, 3),
        ).reviewHistoryFor(StudyCue.fromLanguage),
      },
    );
    expect(recallScore(duplicate, StudyCue.fromLanguage).percentage, 20);
    expect(recallScore(duplicate, StudyCue.fromAudio).percentage, 100);
    expect(recallScore(duplicate, StudyCue.toLanguage).percentage, 0);
  });
  test('Prep remains Upcoming even with past history', () {
    final prep = card(
      List.filled(10, 3),
    ).copyWith(learningStatus: LearningStatus.practice);
    expect(learningStage(prep, StudyCue.fromLanguage), LearningStage.upcoming);
    expect(
      availableForRecall(prep, StudyCue.fromLanguage, DateTime.now()),
      isFalse,
    );
  });
  test('adaptive denominator, exact 80%, and rolling replacement', () {
    expect(
      learningStage(card([3, 3]), StudyCue.fromLanguage),
      LearningStage.current,
    );
    expect(
      learningStage(card(List.filled(8, 3)), StudyCue.fromLanguage),
      LearningStage.past,
    );
    expect(
      learningStage(card([...List.filled(10, 3), 1, 1]), StudyCue.fromLanguage),
      LearningStage.past,
    );
    expect(
      learningStage(
        card([...List.filled(10, 3), 1, 1, 1]),
        StudyCue.fromLanguage,
      ),
      LearningStage.current,
    );
    expect(
      learningStage(card([3, 3, 3, 3]), StudyCue.fromLanguage, window: 5),
      LearningStage.past,
    );
  });
  test('old transliteration stays readable but is never queued', () {
    final c = card([3]);
    expect(c.prompts.map((p) => p.cue), [
      StudyCue.fromLanguage,
      StudyCue.toLanguage,
    ]);
    expect(c.schedules.containsKey(StudyCue.transliteration), isTrue);
  });
  test('Current ignores future schedule; Past respects it', () {
    final now = DateTime.utc(2026, 9, 23);
    expect(availableForRecall(card([1]), StudyCue.fromLanguage, now), isTrue);
    // An initial schedule has no graded timestamp, so it cannot be due.
    expect(
      availableForRecall(card(List.filled(8, 3)), StudyCue.fromLanguage, now),
      isFalse,
    );
  });
}
