import 'package:nx_cards/scheduling/retention.dart';
import 'dart:math';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/scheduling/learning_stage.dart';

class SimilarSoundGroup {
  const SimilarSoundGroup(this.cards, {required this.label});
  final List<StudyCard> cards;
  final String label;
  String get title => similarGroupTitle(label);
  SimilarGroupKind get kind => similarGroupKind(label);
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
List<SimilarSoundGroup> manualSimilarSoundGroups(
  Iterable<StudyCard> cards, {
  bool currentOnly = true,
}) {
  final groups = <String, Map<int, StudyCard>>{};
  for (final card in cards) {
    if (currentOnly && card.learningStatus != LearningStatus.recall) {
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

/// Select complete rounds, each with one front type and its own average score.
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
    for (final cue in StudyCue.activeDirections.where(cues.contains)) {
      final prompts = [
        for (final card in group.cards)
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
  }

  double score(SimilarRecallGroup g) =>
      g.prompts.fold<double>(
        0,
        (sum, p) => sum + recallScore(p.card, p.cue).fraction,
      ) /
      g.prompts.length;
  sessions.shuffle(random);
  final tieOrder = {for (var i = 0; i < sessions.length; i++) sessions[i]: i};
  sessions.sort((a, b) {
    final order = score(a).compareTo(score(b));
    return order == 0 ? tieOrder[a]!.compareTo(tieOrder[b]!) : order;
  });
  final selected = sessions.take(groupLimit).toList()..shuffle(random);
  for (var i = 1; i < selected.length; i++) {
    if (selected[i].label != selected[i - 1].label) continue;
    final next = selected.indexWhere(
      (g) => g.label != selected[i - 1].label,
      i + 1,
    );
    if (next < 0) continue;
    final swap = selected[i];
    selected[i] = selected[next];
    selected[next] = swap;
  }
  return selected;
}

enum SimilarGroupKind { sound, written, other }

SimilarGroupKind similarGroupKind(String id) => id.endsWith('-sound')
    ? SimilarGroupKind.sound
    : id.endsWith('-write')
    ? SimilarGroupKind.written
    : SimilarGroupKind.other;

String similarGroupTitle(String id) =>
    id.replaceFirst(RegExp(r'-(sound|write|other)$'), '');

Iterable<StudyCue> similarGroupCues(SimilarGroupKind kind) => switch (kind) {
  SimilarGroupKind.sound => [StudyCue.fromAudio],
  SimilarGroupKind.written => [StudyCue.fromLanguage, StudyCue.toLanguage],
  SimilarGroupKind.other => StudyCue.activeDirections,
};

double similarWordRetention(StudyCard card, SimilarGroupKind kind) =>
    averageRetention(card, similarGroupCues(kind));

double similarGroupRetention(SimilarSoundGroup group) => group.cards.isEmpty
    ? 0
    : group.cards.fold<double>(
            0,
            (sum, card) => sum + similarWordRetention(card, group.kind),
          ) /
          group.cards.length;

List<SimilarSoundGroup> sortedSimilarGroups(
  Iterable<SimilarSoundGroup> groups,
) => groups.toList()
  ..sort((a, b) {
    final order = a.kind == b.kind
        ? similarGroupRetention(a).compareTo(similarGroupRetention(b))
        : 0;
    return order == 0 ? a.label.compareTo(b.label) : order;
  });

List<SimilarSoundGroup> similarGroupsForCard(
  StudyCard card,
  Iterable<StudyCard> library,
) {
  final content = card.content;
  if (content is! LanguageCardContent || content.similarWordGroups.isEmpty) {
    return [];
  }
  return sortedSimilarGroups(
    manualSimilarSoundGroups(
      [
        ...library.where((c) => c.id != card.id && c.language == card.language),
        card,
      ],
      currentOnly: true,
    ).where((g) => content.similarWordGroups.contains(g.label)),
  );
}
