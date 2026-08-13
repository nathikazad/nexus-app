import 'package:nx_cards/browser/browser.dart';

class CardScheduleStatus {
  const CardScheduleStatus({
    required this.label,
    required this.isDue,
    required this.sortPriority,
    required this.recallPercentage,
  });

  final String label;
  final bool isDue;
  final int sortPriority;
  final int recallPercentage;
}

CardScheduleStatus? cardScheduleStatus(
  StudyCard card,
  DateTime now, {
  int historyWindow = 5,
}) {
  if (card.suspended) {
    return const CardScheduleStatus(
      label: 'Suspended',
      isDue: false,
      sortPriority: 4,
      recallPercentage: 0,
    );
  }

  final schedule = card.scheduleFor(StudyCue.fromLanguage);
  if (!schedule.enabled) return null;

  return CardScheduleStatus(
    label: _stateLabel(schedule),
    isDue: schedule.isDueAt(now),
    sortPriority: _statePriority(schedule),
    recallPercentage: cardRecallPercentage(card, historyWindow: historyWindow),
  );
}

int cardRecallPercentage(StudyCard card, {int historyWindow = 5}) {
  return cueRecallPercentage(
    card,
    StudyCue.fromLanguage,
    historyWindow: historyWindow,
  );
}

int cueRecallPercentage(StudyCard card, StudyCue cue, {int historyWindow = 5}) {
  if (historyWindow <= 0) return 0;
  final reviews = card.reviewHistoryFor(cue).toList()
    ..sort((left, right) => left.reviewedAt.compareTo(right.reviewedAt));
  final recentReviews = reviews.skip(
    (reviews.length - historyWindow).clamp(0, reviews.length),
  );
  final recalled = recentReviews.where((review) => review.rating >= 3).length;
  return (recalled / historyWindow * 100).round();
}

typedef WordScheduleStatus = CardScheduleStatus;

CardScheduleStatus? wordScheduleStatus(
  StudyCard card,
  DateTime now, {
  int historyWindow = 5,
}) => cardScheduleStatus(card, now, historyWindow: historyWindow);

int frontToBackRecallPercentage(StudyCard card, {int historyWindow = 5}) =>
    cardRecallPercentage(card, historyWindow: historyWindow);

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

List<StudyCard> sortCardsByScheduleState(
  Iterable<StudyCard> cards,
  DateTime now, {
  int historyWindow = 5,
}) {
  final sorted = cards.toList(growable: false);
  sorted.sort((left, right) {
    final leftPriority =
        cardScheduleStatus(
          left,
          now,
          historyWindow: historyWindow,
        )?.sortPriority ??
        5;
    final rightPriority =
        cardScheduleStatus(
          right,
          now,
          historyWindow: historyWindow,
        )?.sortPriority ??
        5;
    final byState = leftPriority.compareTo(rightPriority);
    if (byState != 0) return byState;
    if (leftPriority == 2) {
      final leftRecall = cardRecallPercentage(
        left,
        historyWindow: historyWindow,
      );
      final rightRecall = cardRecallPercentage(
        right,
        historyWindow: historyWindow,
      );
      final byRecall = leftRecall.compareTo(rightRecall);
      if (byRecall != 0) return byRecall;
    }
    return left.front.toLowerCase().compareTo(right.front.toLowerCase());
  });
  return sorted;
}

List<StudyCard> sortWordsByScheduleState(
  Iterable<StudyCard> cards,
  DateTime now, {
  int historyWindow = 5,
}) => sortCardsByScheduleState(cards, now, historyWindow: historyWindow);
