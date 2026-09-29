import 'package:nx_cards/browser/browser.dart';

enum LearningStage {
  upcoming,
  current,
  past,
  future;

  String get label => switch (this) {
    upcoming => 'Practice',
    current => 'Weak',
    past => 'Strong',
    future => 'Future',
  };
}

class RecallScore {
  const RecallScore({required this.recalled, required this.attempts});
  final int recalled;
  final int attempts;
  int get denominator => attempts.clamp(5, 10);
  double get fraction => recalled / denominator;
  int get percentage => (fraction * 100).round();
  bool get strong => recalled * 100 >= denominator * 80;
}

RecallScore recallScore(StudyCard card, StudyCue cue) {
  final byId = {
    for (final review in card.reviewHistoryFor(cue)) review.id: review,
  };
  final reviews = byId.values.toList()
    ..sort((a, b) {
      final byTime = b.reviewedAt.compareTo(a.reviewedAt);
      return byTime != 0 ? byTime : b.id.compareTo(a.id);
    });
  final recent = reviews.take(10).toList();
  return RecallScore(
    recalled: recent.where((r) => r.rating >= 3).length,
    attempts: recent.length,
  );
}

LearningStage learningStage(StudyCard card, StudyCue cue, {int window = 10}) {
  if (card.learningStatus == LearningStatus.future) {
    return LearningStage.future;
  }
  if (card.learningStatus == LearningStatus.practice) {
    return LearningStage.upcoming;
  }
  // Compare without rounding: 79.6% must never graduate to Past.
  return recallScore(card, cue).strong
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
      !card.supportsCue(cue) ||
      !card.scheduleFor(cue).enabled ||
      !StudyCue.activeDirections.contains(cue)) {
    return false;
  }
  return learningStage(card, cue, window: window) != LearningStage.past ||
      card.scheduleFor(cue).isDueAt(now);
}
