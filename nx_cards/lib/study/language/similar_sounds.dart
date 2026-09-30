import 'dart:math';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/scheduling/learning_stage.dart';

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

/// Explicit membership only; pronunciation does not affect manual groups.
List<SimilarSoundGroup> manualSimilarSoundGroups(Iterable<StudyCard> cards) {
  final groups = <String, Map<int, StudyCard>>{};
  for (final card in cards) {
    if (card.learningStatus != LearningStatus.recall) {
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

/// Select complete manual groups, with all selected directions inside each group.
/// Retention orders groups but never filters membership or truncates a group.
List<SimilarRecallGroup> manualRecallSession(
  Iterable<StudyCard> cards, {
  required bool sound,
  required Set<StudyCue> directions,
  required int groupLimit,
  Random? random,
}) {
  if (groupLimit < 1) return [];
  final cues = sound
      ? {StudyCue.fromAudio}
      : directions.intersection({StudyCue.fromLanguage, StudyCue.toLanguage});
  if (cues.isEmpty) return [];
  final groups = manualSimilarSoundGroups(cards.where((c) => c.active));
  final sessions = <SimilarRecallGroup>[];
  for (final group in groups) {
    if (!group.label.endsWith(sound ? '-sound' : '-write')) continue;
    final prompts = [
      for (final card in group.cards)
        for (final cue in cues)
          if (card.supportsCue(cue)) StudyPrompt(card: card, cue: cue),
    ];
    if (prompts.isEmpty) continue;
    prompts.shuffle(random);
    sessions.add(
      SimilarRecallGroup(
        prompts: prompts,
        comparisonCards: group.cards,
        label: group.label,
      ),
    );
  }
  double score(SimilarRecallGroup g) =>
      g.prompts.fold<double>(
        0,
        (sum, p) => sum + recallScore(p.card, p.cue).fraction,
      ) /
      g.prompts.length;
  sessions.sort((a, b) {
    final order = score(a).compareTo(score(b));
    return order == 0 ? a.label.compareTo(b.label) : order;
  });
  return sessions.take(groupLimit).toList();
}
