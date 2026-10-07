import 'package:nx_cards/browser/browser.dart';

/// Merge a direct review into fresh data, then credit each contained card once.
/// Results put the parent last, allowing remote retries to repair partial saves.
Future<List<StudyCard>> planRecallSave(
  StudyCard incoming,
  Future<StudyCard> Function(int) load,
) async {
  if (incoming.isSummary) {
    throw StateError('Load the full card before reviewing.');
  }
  final existing = await load(incoming.id);
  final history = {...existing.reviewHistory};
  final schedules = {...existing.schedules};
  final successes = <StudyCue, List<CardReview>>{};
  var changed = false;
  for (final cue in incoming.directions) {
    final previous = existing.reviewHistoryFor(cue);
    final ids = previous.map((r) => r.id).toSet();
    final added = incoming
        .reviewHistoryFor(cue)
        .where((r) => !r.isPhraseCredit && ids.add(r.id))
        .toList();
    if (added.isEmpty) continue;
    changed = true;
    history[cue] = [...previous, ...added]
      ..sort((a, b) => a.reviewedAt.compareTo(b.reviewedAt));
    schedules[cue] = incoming.scheduleFor(cue);
    successes[cue] = added.where((r) => r.rating >= 3).toList();
  }
  if (!changed) return [];
  final result = <StudyCard>[];
  if (existing.isPhraseCard && successes.values.any((r) => r.isNotEmpty)) {
    final visited = <int>{existing.id};
    Future<void> visit(int id) async {
      if (!visited.add(id)) return;
      final child = await load(id);
      if (!child.isLanguageCard || child.language != existing.language) return;
      final childHistory = {...child.reviewHistory};
      var credited = false;
      for (final entry in successes.entries) {
        if (!child.studiesCue(entry.key) ||
            !child.scheduleFor(entry.key).enabled) {
          continue;
        }
        final reviews = [...child.reviewHistoryFor(entry.key)];
        final ids = reviews.map((r) => r.id).toSet();
        for (final review in entry.value) {
          final creditId = CardReview.phraseCreditId(existing.id, review.id);
          if (!ids.add(creditId)) continue;
          credited = true;
          reviews.add(
            CardReview(
              id: creditId,
              reviewedAt: review.reviewedAt,
              rating: review.rating,
              elapsedSeconds: 0,
              scheduledSeconds: 0,
            ),
          );
        }
        childHistory[entry.key] = reviews
          ..sort((a, b) => a.reviewedAt.compareTo(b.reviewedAt));
      }
      if (credited) result.add(child.copyWith(reviewHistory: childHistory));
      for (final linked in child.linkedWordIds) {
        await visit(linked);
      }
    }

    for (final id in existing.linkedWordIds) {
      await visit(id);
    }
  }
  result.add(existing.copyWith(schedules: schedules, reviewHistory: history));
  return result;
}
