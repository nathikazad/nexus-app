import 'package:nx_cards/scheduling/retention.dart';
import 'package:nx_cards/browser/browser.dart';

class SimilarSoundGroup {
  const SimilarSoundGroup(this.cards, {required this.label});
  final List<StudyCard> cards;
  final String label;
  String get title => similarGroupTitle(label);
  SimilarGroupKind get kind => similarGroupKind(label);
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

enum SimilarGroupKind { sound, written, meaning, other }

SimilarGroupKind similarGroupKind(String id) => id.endsWith('-sound')
    ? SimilarGroupKind.sound
    : id.endsWith('-write')
    ? SimilarGroupKind.written
    : id.endsWith('-meaning')
    ? SimilarGroupKind.meaning
    : SimilarGroupKind.other;

String similarGroupTitle(String id) =>
    id.replaceFirst(RegExp(r'-(sound|write|meaning|other)$'), '');

Iterable<RecallComponent> similarGroupCues(SimilarGroupKind kind) =>
    switch (kind) {
      SimilarGroupKind.sound => [RecallComponent.sound],
      SimilarGroupKind.written => [RecallComponent.script],
      SimilarGroupKind.meaning => [RecallComponent.meaning],
      SimilarGroupKind.other => RecallComponent.values,
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
