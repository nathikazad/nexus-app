import 'package:nx_cards/domain/cards_models.dart';

class WordScheduleStatus {
  const WordScheduleStatus({
    required this.label,
    required this.isDue,
    required this.sortPriority,
    this.recallPercentage,
  });

  final String label;
  final bool isDue;
  final int sortPriority;
  final int? recallPercentage;
}

WordScheduleStatus? wordScheduleStatus(StudyCard card, DateTime now) {
  if (card.suspended) {
    return const WordScheduleStatus(
      label: 'Suspended',
      isDue: false,
      sortPriority: 4,
    );
  }

  final schedule = card.scheduleFor(StudyCue.fromLanguage);
  if (!schedule.enabled) return null;

  return WordScheduleStatus(
    label: _stateLabel(schedule),
    isDue: schedule.isDueAt(now),
    sortPriority: _statePriority(schedule),
    recallPercentage: schedule.schedulingState == 'review'
        ? frontToBackRecallPercentage(card)
        : null,
  );
}

int frontToBackRecallPercentage(StudyCard card) {
  final reviews = card.reviewHistoryFor(StudyCue.fromLanguage).toList()
    ..sort((left, right) => left.reviewedAt.compareTo(right.reviewedAt));
  if (reviews.isEmpty) return 0;
  final recentReviews = reviews.skip(
    (reviews.length - 5).clamp(0, reviews.length),
  );
  final recalled = recentReviews.where((review) => review.rating >= 3).length;
  return (recalled / recentReviews.length * 100).round();
}

String _stateLabel(CardSchedule schedule) {
  if (schedule.lastReviewedAt == null) return 'New';
  return switch (schedule.schedulingState) {
    'relearning' => 'Relearning',
    'learning' => 'Learning',
    _ => 'Retained',
  };
}

int _statePriority(CardSchedule schedule) {
  if (schedule.lastReviewedAt == null) return 3;
  return switch (schedule.schedulingState) {
    'learning' => 0,
    'relearning' => 1,
    _ => 2,
  };
}

List<StudyCard> sortWordsByScheduleState(
  Iterable<StudyCard> cards,
  DateTime now,
) {
  final sorted = cards.toList(growable: false);
  sorted.sort((left, right) {
    final leftPriority = wordScheduleStatus(left, now)?.sortPriority ?? 5;
    final rightPriority = wordScheduleStatus(right, now)?.sortPriority ?? 5;
    final byState = leftPriority.compareTo(rightPriority);
    if (byState != 0) return byState;
    if (leftPriority == 2) {
      final leftRecall = frontToBackRecallPercentage(left);
      final rightRecall = frontToBackRecallPercentage(right);
      final byRecall = leftRecall.compareTo(rightRecall);
      if (byRecall != 0) return byRecall;
    }
    return left.front.toLowerCase().compareTo(right.front.toLowerCase());
  });
  return sorted;
}
