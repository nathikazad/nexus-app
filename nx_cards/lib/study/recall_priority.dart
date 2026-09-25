import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/scheduling/learning_stage.dart';

bool isPastDue(
  StudyPrompt prompt,
  DateTime now, {
  required int historyWindow,
}) =>
    learningStage(prompt.card, prompt.cue, window: historyWindow) ==
        LearningStage.past &&
    prompt.card.scheduleFor(prompt.cue).isDueAt(now);

final _priorityScheduler = fsrs.Scheduler(
  desiredRetention: 0.9,
  enableFuzzing: false,
);

/// A selection score, not a probability. Use the same FSRS model as scheduling.
/// Missing/invalid memory estimates get first-review priority to repair them;
/// the outer due-first selection still applies.
double pastRecallPriority(
  StudyPrompt prompt,
  DateTime now, {
  required int historyWindow,
}) {
  final schedule = prompt.schedule;
  final stability = schedule.stability;
  final accuracy =
      recalledAnswers(prompt.card, prompt.cue, historyWindow) / historyWindow;
  var forgetting = 1.0;
  if (stability != null &&
      stability.isFinite &&
      stability > 0 &&
      schedule.lastReviewedAt != null) {
    final memory = fsrs.Card(
      cardId: prompt.cardId,
      state: fsrs.State.review,
      stability: stability,
      difficulty: schedule.difficulty,
      lastReview: schedule.lastReviewedAt!.toUtc(),
      due: schedule.dueAt?.toUtc() ?? now.toUtc(),
    );
    forgetting =
        (1 -
                _priorityScheduler.getCardRetrievability(
                  memory,
                  currentDateTime: now.toUtc(),
                ))
            .clamp(0.0, 1.0);
  }
  return 100 * forgetting * (2 - accuracy);
}

/// Due Past cards first; retain other stage selection and fill remaining slots.
/// Preserve the caller's shuffled order for equal priorities.
void prioritizeRecallPrompts(
  List<StudyPrompt> prompts,
  DateTime now, {
  required int historyWindow,
}) {
  final order = {for (var i = 0; i < prompts.length; i++) prompts[i]: i};
  final stages = {
    for (final p in prompts)
      p: learningStage(p.card, p.cue, window: historyWindow),
  };
  final scores = {
    for (final p in prompts)
      if (stages[p] == LearningStage.past)
        p: pastRecallPriority(p, now, historyWindow: historyWindow),
  };
  prompts.sort((a, b) {
    final aDue = isPastDue(a, now, historyWindow: historyWindow);
    final bDue = isPastDue(b, now, historyWindow: historyWindow);
    if (aDue != bDue) return aDue ? -1 : 1;
    final byStage = stages[a]!.index.compareTo(stages[b]!.index);
    if (byStage != 0) return byStage;
    if (stages[a] == LearningStage.past) {
      final byScore = scores[b]!.compareTo(scores[a]!);
      if (byScore != 0) return byScore;
    }
    return order[a]!.compareTo(order[b]!);
  });
}
