import 'dart:math' as math;

import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/scheduling/learning_stage.dart';

/// Language-local priority, derived from the whole collection before filtering
/// categories or activation. Matches the approved V2 ranking experiment.
Map<int, double> futureCardScores(
  Iterable<StudyCard> cards, {
  required StudyCue cue,
  required int historyWindow,
}) {
  final languages = <String?, List<StudyCard>>{};
  for (final card in cards.where((c) => c.isLanguageCard)) {
    languages.putIfAbsent(card.language, () => []).add(card);
  }
  final scores = <int, double>{};
  for (final collection in languages.values) {
    final byId = {for (final c in collection) c.id: c};
    final occurrences = {for (final c in collection) c.id: 0};
    // Each distinct phrase contributes once, even with repeated paths or cycles.
    for (final phrase in collection.where((c) => c.isPhraseCard)) {
      final visited = <int>{phrase.id};
      final pending = phrase.linkedWordIds.toList();
      while (pending.isNotEmpty) {
        final id = pending.removeLast();
        if (!visited.add(id)) continue;
        final component = byId[id];
        if (component == null) continue;
        occurrences[id] = occurrences[id]! + 1;
        pending.addAll(component.linkedWordIds);
      }
    }
    final maximum = occurrences.values.fold(0, math.max);
    final frequency = {
      for (final entry in occurrences.entries)
        entry.key: maximum == 0
            ? 0.0
            : math.log(1 + entry.value) / math.log(1 + maximum),
    };
    final knowledge = <int, double>{};
    for (final c in collection) {
      knowledge[c.id] = switch (learningStage(c, cue, window: historyWindow)) {
        LearningStage.future => 0,
        LearningStage.upcoming => .1,
        LearningStage.past => 1,
        LearningStage.current =>
          .1 +
              .9 *
                  (recalledAnswers(c, cue, historyWindow) / historyWindow / .8),
      };
    }
    for (final c in collection) {
      final components = c.linkedWordIds.where((id) => id != c.id).toList();
      final familiarity = components.isEmpty
          ? .5
          : components.fold(0.0, (sum, id) => sum + (knowledge[id] ?? 0)) /
                components.length;
      final usefulness = c.isPhraseCard
          ? components.isEmpty
                ? 0.0
                : components.fold(
                        0.0,
                        (sum, id) => sum + (frequency[id] ?? 0),
                      ) /
                      components.length
          : frequency[c.id]!;
      scores[c.id] = 100 * usefulness * (.6 + .4 * familiarity);
    }
  }
  return scores;
}

List<StudyCard> sortFutureCards(
  Iterable<StudyCard> cards,
  Map<int, double> scores,
) => cards.toList()
  ..sort((a, b) {
    final score = (scores[b.id] ?? 0).compareTo(scores[a.id] ?? 0);
    return score != 0 ? score : a.id.compareTo(b.id);
  });
