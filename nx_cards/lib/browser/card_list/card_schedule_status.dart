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
  int historyWindow = 10,
  StudyCue cue = StudyCue.fromLanguage,
}) {
  final stage = learningStage(card, cue, window: historyWindow);
  return CardScheduleStatus(
    label: card.suspended ? 'Suspended' : stage.label,
    isDue:
        !card.suspended &&
        stage == LearningStage.past &&
        card.scheduleFor(cue).isDueAt(now),
    sortPriority: stage.index,
    recallPercentage: cueRecallPercentage(
      card,
      cue,
      historyWindow: historyWindow,
    ),
  );
}

int cardRecallPercentage(
  StudyCard card, {
  int historyWindow = 10,
  StudyCue cue = StudyCue.fromLanguage,
}) => cueRecallPercentage(card, cue, historyWindow: historyWindow);
int cueRecallPercentage(
  StudyCard card,
  StudyCue cue, {
  int historyWindow = 10,
}) => historyWindow <= 0
    ? 0
    : (recalledAnswers(card, cue, historyWindow) * 100 / historyWindow).round();
typedef WordScheduleStatus = CardScheduleStatus;
CardScheduleStatus? wordScheduleStatus(
  StudyCard card,
  DateTime now, {
  int historyWindow = 10,
}) => cardScheduleStatus(card, now, historyWindow: historyWindow);
int frontToBackRecallPercentage(StudyCard card, {int historyWindow = 10}) =>
    cardRecallPercentage(card, historyWindow: historyWindow);
List<StudyCard> sortCardsByScheduleState(
  Iterable<StudyCard> cards,
  DateTime now, {
  int historyWindow = 10,
  StudyCue cue = StudyCue.fromLanguage,
}) {
  return cards.toList()..sort((a, b) {
    final byStage = learningStage(
      a,
      cue,
      window: historyWindow,
    ).index.compareTo(learningStage(b, cue, window: historyWindow).index);
    if (byStage != 0) return byStage;
    final byRecall = recalledAnswers(
      a,
      cue,
      historyWindow,
    ).compareTo(recalledAnswers(b, cue, historyWindow));
    return byRecall != 0
        ? byRecall
        : a.front.toLowerCase().compareTo(b.front.toLowerCase());
  });
}

List<StudyCard> sortWordsByScheduleState(
  Iterable<StudyCard> cards,
  DateTime now, {
  int historyWindow = 10,
  StudyCue cue = StudyCue.fromLanguage,
}) => sortCardsByScheduleState(
  cards,
  now,
  historyWindow: historyWindow,
  cue: cue,
);
