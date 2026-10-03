import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/scheduling/learning_stage.dart';

/// Average direction scores, without pooling attempts or rounding first.
double averageRetention(StudyCard card, Iterable<StudyCue> directions) {
  final cues = (card.isLanguageCard ? directions : [StudyCue.fromLanguage])
      .where(card.studiesCue)
      .toSet();
  if (cues.isEmpty) return 0;
  return cues
          .map((cue) => recallScore(card, cue).fraction)
          .reduce((a, b) => a + b) /
      cues.length;
}

List<StudyCard> retentionCards(
  Iterable<StudyCard> cards,
  Set<StudyCue> directions, {
  double minimum = 0,
  double maximum = 1,
  bool weakOnly = false,
}) {
  final result = cards.where((card) {
    final score = averageRetention(card, directions);
    return card.learningStatus == LearningStatus.recall &&
        score + 1e-9 >= minimum &&
        score <= maximum + 1e-9 &&
        (!weakOnly || score < .8 - 1e-9);
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
  Set<StudyCue> directions, {
  double minimum = 0,
  double maximum = 1,
  bool weakOnly = false,
}) {
  final result = <StudyPrompt>[
    for (final card in retentionCards(
      cards,
      directions,
      minimum: minimum,
      maximum: maximum,
      weakOnly: weakOnly,
    ))
      if (card.active && !card.suspended)
        for (final cue
            in (card.isLanguageCard ? directions : {StudyCue.fromLanguage}))
          if (card.supportsCue(cue) && card.scheduleFor(cue).enabled)
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
