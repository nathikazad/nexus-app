import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/scheduling/learning_stage.dart';

/// Average direction scores, without pooling attempts or rounding first.
double averageRetention(
  StudyCard card,
  Iterable<RecallComponent> directions, {
  int window = 10,
}) {
  final cues = selectedCues(card, directions);
  if (cues.isEmpty) return 0;
  return cues.fold<int>(
        0,
        (sum, cue) => sum + recallScore(card, cue, window: window).recalled,
      ) /
      (cues.length * window);
}

List<StudyCard> retentionCards(
  Iterable<StudyCard> cards,
  Set<RecallComponent> directions, {
  int window = 10,
  double minimum = 0,
  double maximum = 1,
  bool weakOnly = false,
}) {
  final result = cards.where((card) {
    final score = averageRetention(card, directions, window: window);
    return card.learningStatus == LearningStatus.recall &&
        score + 1e-9 >= minimum &&
        score <= maximum + 1e-9 &&
        (!weakOnly || score < .8 - 1e-9);
  }).toList();
  result.sort((a, b) {
    final score = averageRetention(
      a,
      directions,
      window: window,
    ).compareTo(averageRetention(b, directions, window: window));
    return score != 0 ? score : a.id.compareTo(b.id);
  });
  return result;
}

List<StudyPrompt> retentionPrompts(
  Iterable<StudyCard> cards,
  Set<RecallComponent> directions, {
  int window = 10,
  bool writing = true,
  double minimum = 0,
  double maximum = 1,
  bool weakOnly = false,
}) {
  final result = <StudyPrompt>[
    for (final card in retentionCards(
      cards,
      directions,
      window: window,
      minimum: minimum,
      maximum: maximum,
      weakOnly: weakOnly,
    ))
      if (card.active && !card.suspended)
        for (final cue in selectedCues(card, directions))
          if (card.supportsCue(cue) &&
              card.scheduleFor(cue).enabled &&
              (writing || cue.target != RecallComponent.script))
            StudyPrompt(card: card, cue: cue),
  ];
  result.sort((a, b) {
    final score = recallScore(
      a.card,
      a.cue,
      window: window,
    ).fraction.compareTo(recallScore(b.card, b.cue, window: window).fraction);
    if (score != 0) return score;
    final id = a.cardId.compareTo(b.cardId);
    return id != 0 ? id : a.cue.index.compareTo(b.cue.index);
  });
  return result;
}
