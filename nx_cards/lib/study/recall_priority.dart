import 'dart:math';
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
  final accuracy = recallScore(prompt.card, prompt.cue).fraction;
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

/// Weakest card-direction scores first, preserving order for ties.
void prioritizeRecallPrompts(
  List<StudyPrompt> prompts,
  DateTime now, {
  required int historyWindow,
}) {
  final order = {for (var i = 0; i < prompts.length; i++) prompts[i]: i};
  prompts.sort((a, b) {
    final score = recallScore(
      a.card,
      a.cue,
    ).fraction.compareTo(recallScore(b.card, b.cue).fraction);
    return score != 0 ? score : order[a]!.compareTo(order[b]!);
  });
}

/// The priority order decides membership, never the order of the actual round.
List<StudyPrompt> shuffledRecallSelection(
  List<StudyPrompt> prioritized,
  int count, {
  Random? random,
}) => prioritized.take(max(0, count)).toList()..shuffle(random);
