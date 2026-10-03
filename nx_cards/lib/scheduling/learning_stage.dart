import 'package:nx_cards/browser/browser.dart';

enum LearningStage {
  upcoming,
  current,
  past,
  future;

  String get label => switch (this) {
    upcoming => 'Upcoming',
    current => 'Current',
    past => 'Current',
    future => 'Backlog',
  };
}

class RecallScore {
  const RecallScore({
    required this.recalled,
    required this.attempts,
    this.denominator = 10,
  });
  final int recalled;
  final int attempts;
  final int denominator;
  double get fraction => denominator == 0 ? 0 : recalled / denominator;
  int get percentage => (fraction * 100).round();
  bool get strong => denominator > 0 && recalled * 100 >= denominator * 80;
}

Set<StudyCue> selectionCues(StudyCard card, RecallSelection? selection) =>
    switch (selection) {
      null => selectedCues(card, RecallComponent.values),
      RecallComponent component => selectedCues(card, [component]),
      StudyCue cue => {
        if (card.studiesCue(cue) && card.scheduleFor(cue).enabled) cue,
      },
      _ => throw ArgumentError.value(selection),
    };

List<CardReview> selectionReviews(StudyCard card, RecallSelection? selection) =>
    [
      for (final cue in selectionCues(card, selection))
        ...card.reviewHistoryFor(cue),
    ]..sort((a, b) => b.reviewedAt.compareTo(a.reviewedAt));

final _scoreCache = Expando<Map<(RecallSelection?, int), RecallScore>>(
  'recall scores',
);

RecallScore recallScore(
  StudyCard card,
  RecallSelection? selection, {
  int window = 10,
}) {
  assert(window >= 1 && window <= 10);
  final cache = _scoreCache[card] ??= {};
  final cached = cache[(selection, window)];
  if (cached != null) return cached;
  final cues = selectionCues(card, selection);
  var recalled = 0;
  var attempts = 0;
  for (final cue in cues) {
    final byId = {
      for (final review in card.reviewHistoryFor(cue)) review.id: review,
    };
    final reviews = byId.values.toList()
      ..sort((a, b) {
        final byTime = b.reviewedAt.compareTo(a.reviewedAt);
        return byTime != 0 ? byTime : b.id.compareTo(a.id);
      });
    final recent = reviews.take(window);
    recalled += recent.where((r) => r.rating >= 3).length;
    attempts += recent.length;
  }
  return cache[(selection, window)] = RecallScore(
    recalled: recalled,
    attempts: attempts,
    denominator: cues.length * window,
  );
}

LearningStage learningStage(
  StudyCard card,
  RecallSelection? cue, {
  int window = 10,
}) {
  if (card.learningStatus == LearningStatus.future) {
    return LearningStage.future;
  }
  if (card.learningStatus == LearningStatus.practice) {
    return LearningStage.upcoming;
  }
  // Compare without rounding: 79.6% must never graduate to Past.
  return recallScore(card, cue, window: window).strong
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
      !card.directions.contains(cue)) {
    return false;
  }
  return learningStage(card, cue, window: window) != LearningStage.past ||
      card.scheduleFor(cue).isDueAt(now);
}
