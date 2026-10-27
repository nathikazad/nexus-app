import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/scheduling/learning_stage.dart';

/// A card is new only before its first review in any direction, including
/// directions that are currently disabled or outside the selected skills.
bool isUnreviewedCard(StudyCard card) =>
    card.reviewHistory.values.every((reviews) => reviews.isEmpty) &&
    card.schedules.values.every(
      (schedule) =>
          schedule.reviewCount == 0 && schedule.lastReviewedAt == null,
    );

/// Overall card gauge averages the selected Meaning/Sound/Script scores.
double averageRetention(StudyCard card, Iterable<RecallComponent> directions) =>
    combinedRecallScore(card, directions).fraction;

bool matchesRecallRange(
  StudyCard card,
  StudyCue cue, {
  double minimum = 0,
  double maximum = 1,
  bool weakOnly = false,
  bool newOnly = false,
}) {
  if (newOnly) return isUnreviewedCard(card);
  final score = recallScore(card, cue).fraction;
  return score + 1e-9 >= minimum &&
      score <= maximum + 1e-9 &&
      (!weakOnly || score < .8 - 1e-9);
}

List<StudyCard> retentionCards(
  Iterable<StudyCard> cards,
  Set<RecallComponent> directions, {
  double minimum = 0,
  double maximum = 1,
  bool weakOnly = false,
  bool newOnly = false,
}) {
  final result = cards.where((card) {
    final score = averageRetention(card, directions);
    return card.learningStatus == LearningStatus.recall &&
        (newOnly
            ? isUnreviewedCard(card)
            : score + 1e-9 >= minimum &&
                  score <= maximum + 1e-9 &&
                  (!weakOnly || score < .8 - 1e-9));
  }).toList();
  result.sort((a, b) {
    final score = averageRetention(
      a,
      directions,
    ).compareTo(averageRetention(b, directions));
    return score != 0 ? score : a.id.compareTo(b.id);
  });
  return result;
}

List<StudyPrompt> retentionPrompts(
  Iterable<StudyCard> cards,
  Set<RecallComponent> directions, {
  bool writing = true,
  bool sound = true,
  double minimum = 0,
  double maximum = 1,
  bool weakOnly = false,
  bool newOnly = false,
}) {
  final result = <StudyPrompt>[
    for (final card in cards)
      if (card.active &&
          !card.suspended &&
          card.learningStatus == LearningStatus.recall)
        for (final cue in selectedCues(card, directions))
          if (card.supportsCue(cue) &&
              card.scheduleFor(cue).enabled &&
              (writing || cue.target != RecallComponent.script) &&
              (sound ||
                  (cue.source != RecallComponent.sound &&
                      cue.target != RecallComponent.sound)) &&
              matchesRecallRange(
                card,
                cue,
                minimum: minimum,
                maximum: maximum,
                weakOnly: weakOnly,
                newOnly: newOnly,
              ))
            StudyPrompt(card: card, cue: cue),
  ];
  result.sort((a, b) {
    final score = recallScore(
      a.card,
      a.cue,
    ).fraction.compareTo(recallScore(b.card, b.cue).fraction);
    if (score != 0) return score;
    final id = a.cardId.compareTo(b.cardId);
    return id != 0 ? id : a.cue.index.compareTo(b.cue.index);
  });
  return result;
}
