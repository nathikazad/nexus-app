import 'package:nx_cards/browser/browser.dart';

/// Overlap local database/file I/O without opening the entire library at once.
/// Preserve queue order and reuse duplicate cards (e.g. multiple recall cues).
Future<List<StudyCard>> hydrateStudyQueue(
  List<StudyCard> cards,
  Future<StudyCard> Function(StudyCard) load,
) async {
  final unique = {for (final card in cards) card.id: card};
  final pending = unique.values.toList();
  final loaded = <int, StudyCard>{};
  var next = 0;
  Future<void> worker() async {
    while (next < pending.length) {
      final card = pending[next++];
      loaded[card.id] = card.isSummary ? await load(card) : card;
    }
  }

  await Future.wait([
    for (var i = 0; i < 8 && i < pending.length; i++) worker(),
  ]);
  return [for (final card in cards) loaded[card.id]!];
}
