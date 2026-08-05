import 'package:nx_cards/domain/card/study_card.dart';
import 'package:nx_cards/domain/card/study_prompt.dart';
import 'package:nx_cards/domain/deck/card_deck.dart';

class CardsDashboard {
  const CardsDashboard({required this.decks, required this.cards});

  final List<CardDeck> decks;
  final List<StudyCard> cards;

  Iterable<StudyPrompt> _prompts({int? deckId}) => cards
      .where((card) => deckId == null || card.deckId == deckId)
      .expand((card) => card.prompts);

  int dueCount(DateTime now, {int? deckId}) =>
      _prompts(deckId: deckId).where((prompt) => prompt.isDueAt(now)).length;

  int newCount({int? deckId}) =>
      _prompts(deckId: deckId).where((prompt) => prompt.isNew).length;

  int cardCount(int deckId) =>
      cards.where((card) => card.deckId == deckId).length;

  List<StudyPrompt> studyQueue(
    DateTime now, {
    int? deckId,
    int newCardLimit = 20,
  }) {
    final eligible = _prompts(deckId: deckId);
    final due = eligible.where((prompt) => prompt.isDueAt(now)).toList()
      ..sort(
        (a, b) => (a.schedule.dueAt ?? now).compareTo(b.schedule.dueAt ?? now),
      );
    final fresh =
        eligible.where((prompt) => prompt.isNew).take(newCardLimit).toList()
          ..sort((a, b) {
            final direction = a.direction.index.compareTo(b.direction.index);
            return direction != 0 ? direction : a.cardId.compareTo(b.cardId);
          });
    return _separateSiblingPrompts(<StudyPrompt>[...due, ...fresh]);
  }
}

List<StudyPrompt> _separateSiblingPrompts(List<StudyPrompt> source) {
  final remaining = [...source];
  final result = <StudyPrompt>[];
  while (remaining.isNotEmpty) {
    var index = 0;
    if (result.isNotEmpty) {
      final alternative = remaining.indexWhere(
        (prompt) => prompt.cardId != result.last.cardId,
      );
      if (alternative >= 0) index = alternative;
    }
    result.add(remaining.removeAt(index));
  }
  return result;
}
