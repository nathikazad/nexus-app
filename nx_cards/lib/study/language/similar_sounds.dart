import 'dart:math';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/scheduling/learning_stage.dart';

bool isChineseLanguage(String? value) => {
  'chinese',
  'mandarin',
  'zh',
  'zh-cn',
  'zh-tw',
}.contains(value?.trim().toLowerCase());

class SimilarSoundGroup {
  const SimilarSoundGroup(this.cards, {required this.label});
  final List<StudyCard> cards;
  final String label;
}

class SimilarRecallGroup {
  const SimilarRecallGroup({
    required this.prompts,
    required this.comparisonCards,
    this.label = 'Similar words',
  });
  final List<StudyPrompt> prompts;
  final List<StudyCard> comparisonCards;
  final String label;
}

/// Rank groups by average retention in this direction. Comparisons retain the
/// full group even when the remaining question budget cuts a group short.
List<SimilarRecallGroup> similarSoundRecallGroups(
  List<StudyPrompt> candidates, {
  required int limit,
  Random? random,
}) {
  if (candidates.isEmpty || limit < 1) return [];
  final cue = candidates.first.cue;
  if (candidates.any((p) => p.cue != cue)) return [];
  final prompts = {for (final p in candidates) p.cardId: p};
  final groups = manualRecallGroups(prompts.values.map((p) => p.card), cue);
  double score(SimilarSoundGroup g) =>
      g.cards.fold<double>(0, (sum, c) => sum + recallScore(c, cue).fraction) /
      g.cards.length;
  groups.sort((a, b) {
    final order = score(a).compareTo(score(b));
    return order != 0 ? order : a.cards.first.id.compareTo(b.cards.first.id);
  });
  final result = <SimilarRecallGroup>[];
  var left = limit;
  for (final group in groups) {
    if (left == 0) break;
    final questions = [for (final c in group.cards) prompts[c.id]!];
    questions.shuffle(random);
    final chosen = questions.take(left).toList();
    if (chosen.isEmpty) continue;
    result.add(
      SimilarRecallGroup(
        prompts: chosen,
        comparisonCards: group.cards,
        label: group.label,
      ),
    );
    left -= chosen.length;
  }
  return result;
}

/// Explicit membership only; pronunciation does not affect manual groups.
List<SimilarSoundGroup> manualSimilarSoundGroups(Iterable<StudyCard> cards) {
  final groups = <String, Map<int, StudyCard>>{};
  for (final card in cards) {
    if (!isChineseLanguage(card.language) ||
        card.learningStatus != LearningStatus.recall) {
      continue;
    }
    final content = card.content;
    if (content is! LanguageCardContent) continue;
    for (final id in content.similarWordGroups) {
      if (id.isEmpty || id.trim() != id) continue;
      (groups[id] ??= {})[card.id] = card;
    }
  }
  return [
    for (final entry in groups.entries)
      SimilarSoundGroup(entry.value.values.toList(), label: entry.key),
  ]..sort((a, b) {
    final size = b.cards.length.compareTo(a.cards.length);
    return size == 0 ? a.label.compareTo(b.label) : size;
  });
}

/// The direction determines which explicit, suffixed memberships are eligible.
List<SimilarSoundGroup> manualRecallGroups(
  Iterable<StudyCard> cards,
  StudyCue cue,
) {
  final suffix = switch (cue) {
    StudyCue.fromAudio => '-sound',
    StudyCue.fromLanguage || StudyCue.toLanguage => '-write',
    _ => null,
  };
  if (suffix == null) return [];
  return manualSimilarSoundGroups(
    cards,
  ).where((group) => group.label.endsWith(suffix)).toList();
}
