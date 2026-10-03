import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/scheduling/learning_stage.dart';

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
  RecallSelection? cue,
}) {
  final stage = learningStage(card, cue);
  return CardScheduleStatus(
    label: card.suspended ? 'Suspended' : stage.label,
    isDue:
        !card.suspended &&
        stage == LearningStage.past &&
        selectionCues(
          card,
          cue,
        ).any((direction) => card.scheduleFor(direction).isDueAt(now)),
    sortPriority: stage.index,
    recallPercentage: cueRecallPercentage(card, cue),
  );
}

int cardRecallPercentage(StudyCard card, {RecallSelection? cue}) =>
    cueRecallPercentage(card, cue);
int cueRecallPercentage(StudyCard card, RecallSelection? cue) =>
    recallScore(card, cue).percentage;
typedef WordScheduleStatus = CardScheduleStatus;
CardScheduleStatus? wordScheduleStatus(StudyCard card, DateTime now) =>
    cardScheduleStatus(card, now);
int frontToBackRecallPercentage(StudyCard card) => cardRecallPercentage(card);
List<StudyCard> sortCardsByScheduleState(
  Iterable<StudyCard> cards,
  DateTime now, {
  RecallSelection? cue,
}) {
  return cards.toList()..sort((a, b) {
    final byStage = learningStage(
      a,
      cue,
    ).index.compareTo(learningStage(b, cue).index);
    if (byStage != 0) return byStage;
    final byRecall = recallScore(
      a,
      cue,
    ).fraction.compareTo(recallScore(b, cue).fraction);
    return byRecall != 0
        ? byRecall
        : a.front.toLowerCase().compareTo(b.front.toLowerCase());
  });
}

List<StudyCard> sortWordsByScheduleState(
  Iterable<StudyCard> cards,
  DateTime now, {
  RecallSelection? cue,
}) => sortCardsByScheduleState(cards, now, cue: cue);
