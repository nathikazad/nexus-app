import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/scheduling/scheduling.dart';

/// A group decision is fixed once saving starts. Reuse prepared review IDs on
/// retry, and never re-save completed members after a partial write failure.
class GroupGradeBatch {
  GroupGradeBatch({
    required List<StudyPrompt> prompts,
    required Map<int, StudyCard> latest,
    required CardScheduler scheduler,
    required DateTime now,
    required this.rating,
  }) : updates = [
         for (final prompt in prompts)
           scheduler
               .preview(
                 prompt.withCard(latest[prompt.cardId] ?? prompt.card),
                 now,
               )[rating]!
               .card,
       ];
  final CardRating rating;
  final List<StudyCard> updates;
  int _saved = 0;
  bool _saving = false;
  bool get complete => _saved == updates.length;

  Future<void> save(
    Future<void> Function(StudyCard) saveCard,
    Map<int, StudyCard> latest,
  ) async {
    if (_saving) return;
    _saving = true;
    try {
      while (_saved < updates.length) {
        final card = updates[_saved];
        await saveCard(card);
        latest[card.id] = card;
        _saved++;
      }
    } finally {
      _saving = false;
    }
  }
}
