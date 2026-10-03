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
    this.denominator = recallWindow,
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

/// Every skill and direction uses five slots, including unattempted slots.
const recallWindow = 5;

RecallScore pooledRecallScore(
  StudyCard card,
  Iterable<StudyCue> cues, {
  Map<StudyCue, List<CardReview>>? history,
}) {
  final unique = <(StudyCue, String), CardReview>{
    for (final cue in cues)
      for (final review
          in (history ?? card.reviewHistory)[cue] ?? <CardReview>[])
        (cue, review.id): review,
  };
  final reviews = unique.entries.toList()
    ..sort((a, b) {
      final time = b.value.reviewedAt.compareTo(a.value.reviewedAt);
      if (time != 0) return time;
      final id = b.value.id.compareTo(a.value.id);
      return id != 0 ? id : b.key.$1.index.compareTo(a.key.$1.index);
    });
  final recent = reviews.take(recallWindow).map((entry) => entry.value);
  return RecallScore(
    recalled: recent.where((review) => review.rating >= 3).length,
    attempts: recent.length,
  );
}

final _combinedScoreCache = Expando<Map<int, RecallScore>>(
  'combined skill scores',
);

/// Average selected skill scores; each skill pools its latest five recalls.
/// An event may inform two skills, but is only one event in the history graph.
RecallScore combinedRecallScore(
  StudyCard card,
  Iterable<RecallComponent> components, {
  Map<StudyCue, List<CardReview>>? history,
}) {
  if (!card.isLanguageCard) {
    return pooledRecallScore(
      card,
      selectedCues(card, components),
      history: history,
    );
  }
  final selected = components.toSet()
    ..removeWhere(
      (component) => card.spokenOnly && component == RecallComponent.script,
    );
  final mask = selected.fold<int>(0, (bits, c) => bits | (1 << c.index));
  final cache = history == null ? (_combinedScoreCache[card] ??= {}) : null;
  final cached = cache?[mask];
  if (cached != null) return cached;
  final scores = [
    for (final component in selected)
      history == null
          ? recallScore(card, component)
          : pooledRecallScore(
              card,
              selectedCues(card, [component]),
              history: history,
            ),
  ];
  final result = RecallScore(
    recalled: scores.fold(0, (sum, score) => sum + score.recalled),
    attempts: scores.fold(0, (sum, score) => sum + score.attempts),
    denominator: recallWindow * scores.length,
  );
  if (cache != null) cache[mask] = result;
  return result;
}

final _scoreCache = Expando<Map<RecallSelection?, RecallScore>>(
  'fixed five recall',
);
RecallScore recallScore(StudyCard card, RecallSelection? selection) {
  final cache = _scoreCache[card] ??= {};
  return cache.putIfAbsent(
    selection,
    () => selection == null
        ? combinedRecallScore(card, RecallComponent.values)
        : pooledRecallScore(card, selectionCues(card, selection)),
  );
}

LearningStage learningStage(StudyCard card, RecallSelection? cue) {
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

bool availableForRecall(StudyCard card, StudyCue cue, DateTime now) {
  if (card.suspended ||
      !card.active ||
      !card.supportsCue(cue) ||
      !card.scheduleFor(cue).enabled ||
      !card.directions.contains(cue)) {
    return false;
  }
  return learningStage(card, cue) != LearningStage.past ||
      card.scheduleFor(cue).isDueAt(now);
}
