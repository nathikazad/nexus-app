import 'dart:math';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/scheduling/learning_stage.dart';

bool isPastDue(StudyPrompt prompt, DateTime now) =>
    learningStage(prompt.card, prompt.cue) == LearningStage.past &&
    prompt.card.scheduleFor(prompt.cue).isDueAt(now);

final _priorityScheduler = fsrs.Scheduler(
  desiredRetention: 0.9,
  enableFuzzing: false,
);

/// A selection score, not a probability. Use the same FSRS model as scheduling.
/// Missing/invalid memory estimates get first-review priority to repair them;
/// the outer due-first selection still applies.
double pastRecallPriority(StudyPrompt prompt, DateTime now) {
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

/// Weakest card-direction scores first, with randomized selection among ties.
void prioritizeRecallPrompts(
  List<StudyPrompt> prompts,
  DateTime now, {
  Random? random,
}) {
  prompts.shuffle(random ?? Random.secure());
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
}) => spaceRepeatedRecallCards(
  prioritized.take(max(0, count)).toList()..shuffle(random),
);

/// Keep every selected front, spacing repetitions of the same card as far
/// apart as the deck permits. Shuffled order breaks equal-frequency ties.
List<StudyPrompt> spaceRepeatedRecallCards(List<StudyPrompt> shuffled) {
  final buckets = <int, List<StudyPrompt>>{};
  for (final prompt in shuffled) {
    (buckets[prompt.cardId] ??= []).add(prompt);
  }
  if (buckets.length == shuffled.length || shuffled.isEmpty) {
    return List.of(shuffled);
  }
  final largest = buckets.values.map((items) => items.length).reduce(max);
  final tiedLargest = buckets.values
      .where((items) => items.length == largest)
      .length;
  final maximumGap = (shuffled.length - tiedLargest) ~/ (largest - 1);
  for (var gap = maximumGap; gap >= 1; gap--) {
    final used = <int, int>{};
    final nextAllowed = <int, int>{};
    final result = <StudyPrompt>[];
    while (result.length < shuffled.length) {
      int? chosen;
      var mostRemaining = 0;
      for (final entry in buckets.entries) {
        final remaining = entry.value.length - (used[entry.key] ?? 0);
        if (remaining > mostRemaining &&
            (nextAllowed[entry.key] ?? 0) <= result.length) {
          chosen = entry.key;
          mostRemaining = remaining;
        }
      }
      if (chosen == null) break;
      final offset = used[chosen] ?? 0;
      nextAllowed[chosen] = result.length + gap;
      result.add(buckets[chosen]![offset]);
      used[chosen] = offset + 1;
    }
    if (result.length == shuffled.length) return result;
  }
  return List.of(shuffled);
}
