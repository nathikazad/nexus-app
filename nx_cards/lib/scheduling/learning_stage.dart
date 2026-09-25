import 'package:nx_cards/browser/browser.dart';

enum LearningStage {
  upcoming,
  current,
  past,
  future;

  String get label => switch (this) {
    upcoming => 'Upcoming',
    current => 'Current',
    past => 'Past',
    future => 'Future',
  };
}

int recalledAnswers(StudyCard card, StudyCue cue, int window) {
  if (window <= 0) throw ArgumentError.value(window, 'window');
  final byId = {
    for (final review in card.reviewHistoryFor(cue)) review.id: review,
  };
  final reviews = byId.values.toList()
    ..sort((a, b) {
      final byTime = b.reviewedAt.compareTo(a.reviewedAt);
      return byTime != 0 ? byTime : b.id.compareTo(a.id);
    });
  return reviews.take(window).where((r) => r.rating >= 3).length;
}

LearningStage learningStage(StudyCard card, StudyCue cue, {int window = 10}) {
  if (card.learningStatus == LearningStatus.inactive) {
    return LearningStage.future;
  }
  if (card.learningStatus == LearningStatus.prep) return LearningStage.upcoming;
  // Compare without rounding: 79.6% must never graduate to Past.
  return recalledAnswers(card, cue, window) * 100 >= window * 80
      ? LearningStage.past
      : LearningStage.current;
}

bool availableForRecall(
  StudyCard card,
  StudyCue cue,
  DateTime now, {
  int window = 10,
}) {
  if (card.suspended ||
      !card.active ||
      !card.scheduleFor(cue).enabled ||
      !StudyCue.activeDirections.contains(cue)) {
    return false;
  }
  return learningStage(card, cue, window: window) != LearningStage.past ||
      card.scheduleFor(cue).isDueAt(now);
}
