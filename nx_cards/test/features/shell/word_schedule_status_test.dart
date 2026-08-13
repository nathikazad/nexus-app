import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/features/shell/word_schedule_status.dart';

void main() {
  test('shows state and due from front-to-back only', () {
    final now = DateTime.utc(2026, 8, 11, 12);
    final card = _card(
      schedules: {
        StudyCue.fromLanguage: _schedule(
          state: 'learning',
          dueAt: now.subtract(const Duration(minutes: 5)),
        ),
        StudyCue.toLanguage: _schedule(
          state: 'relearning',
          dueAt: now.subtract(const Duration(minutes: 1)),
        ),
        StudyCue.transliteration: _schedule(
          state: 'learning',
          dueAt: now.add(const Duration(minutes: 10)),
        ),
      },
    );

    final status = wordScheduleStatus(card, now);

    expect(status?.label, 'Learning');
    expect(status?.isDue, isTrue);
  });

  test('ignores due state from other directions', () {
    final now = DateTime.utc(2026, 8, 11, 12);
    final card = _card(
      schedules: {
        StudyCue.fromLanguage: _schedule(
          state: 'review',
          dueAt: now.add(const Duration(days: 2)),
        ),
        StudyCue.toLanguage: _schedule(
          state: 'relearning',
          dueAt: now.subtract(const Duration(minutes: 10)),
        ),
      },
    );

    final status = wordScheduleStatus(card, now);

    expect(status?.label, 'Retained');
    expect(status?.isDue, isFalse);
  });

  test('identifies an unreviewed direction as new', () {
    final card = _card(
      schedules: const {
        StudyCue.fromLanguage: CardSchedule.initial(enabled: true),
      },
    );

    final status = wordScheduleStatus(card, DateTime.utc(2026, 8, 11));

    expect(status?.label, 'New');
    expect(status?.isDue, isFalse);
  });

  test('recall percentage uses only the five most recent reviews', () {
    final card = _card(
      schedules: {
        StudyCue.fromLanguage: _schedule(
          state: 'review',
          dueAt: DateTime.utc(2026, 8, 12),
        ),
      },
      recallRatings: const [4, 1, 1, 1, 3, 3],
    );

    final status = wordScheduleStatus(card, DateTime.utc(2026, 8, 11));

    expect(status?.recallPercentage, 40);
  });

  test('recall percentage honors the configured history window', () {
    final card = _card(
      schedules: {
        StudyCue.fromLanguage: _schedule(
          state: 'review',
          dueAt: DateTime.utc(2026, 8, 12),
        ),
      },
      recallRatings: const [4, 4, 1, 1, 3],
    );

    final status = wordScheduleStatus(
      card,
      DateTime.utc(2026, 8, 11),
      historyWindow: 3,
    );

    expect(status?.recallPercentage, 33);
  });

  test('recall percentage keeps the full window as denominator', () {
    final oneOfTwo = _card(
      schedules: {
        StudyCue.fromLanguage: _schedule(
          state: 'review',
          dueAt: DateTime.utc(2026, 8, 12),
        ),
      },
      recallRatings: const [3, 1],
    );
    final neverReviewed = _card(
      schedules: const {
        StudyCue.fromLanguage: CardSchedule.initial(enabled: true),
      },
    );

    expect(frontToBackRecallPercentage(oneOfTwo), 20);
    expect(frontToBackRecallPercentage(neverReviewed), 0);
  });
}

StudyCard _card({
  required Map<StudyCue, CardSchedule> schedules,
  List<int> recallRatings = const <int>[],
}) => StudyCard(
  id: 1,
  content: const LanguageCardContent(
    english: 'worry',
    originalScript: 'ആശങ്ക',
    transliteration: 'aashanka',
  ),
  deckId: 1,
  deckName: 'Malayalam nouns',
  schedules: schedules,
  reviewHistory: <StudyCue, List<CardReview>>{
    if (recallRatings.isNotEmpty)
      StudyCue.fromLanguage: <CardReview>[
        for (var index = 0; index < recallRatings.length; index++)
          CardReview(
            id: 'review-$index',
            reviewedAt: DateTime.utc(2026, 8, index + 1),
            rating: recallRatings[index],
            elapsedSeconds: 86400,
            scheduledSeconds: 86400,
          ),
      ],
  },
  suspended: false,
  learningStatus: LearningStatus.learning,
);

CardSchedule _schedule({required String state, required DateTime dueAt}) =>
    CardSchedule(
      enabled: true,
      dueAt: dueAt,
      lastReviewedAt: dueAt.subtract(const Duration(days: 1)),
      stability: 1,
      difficulty: 5,
      schedulingState: state,
      learningStep: state == 'review' ? null : 0,
      reviewCount: 1,
      lapseCount: 0,
    );
