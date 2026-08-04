import 'package:nx_cards/domain/card/study_card.dart';
import 'package:nx_cards/domain/deck/card_deck.dart';

class CardsDashboard {
  const CardsDashboard({required this.decks, required this.cards});

  final List<CardDeck> decks;
  final List<StudyCard> cards;

  int dueCount(DateTime now, {int? deckId}) => cards
      .where(
        (card) =>
            (deckId == null || card.deckId == deckId) && card.isDueAt(now),
      )
      .length;

  int newCount({int? deckId}) => cards
      .where(
        (card) =>
            !card.suspended &&
            card.isNew &&
            (deckId == null || card.deckId == deckId),
      )
      .length;

  int cardCount(int deckId) =>
      cards.where((card) => card.deckId == deckId).length;

  List<StudyCard> studyQueue(
    DateTime now, {
    int? deckId,
    int newCardLimit = 20,
  }) {
    final eligible = cards.where(
      (card) => !card.suspended && (deckId == null || card.deckId == deckId),
    );
    final due = eligible.where((card) => card.isDueAt(now)).toList()
      ..sort((a, b) => (a.dueAt ?? now).compareTo(b.dueAt ?? now));
    final fresh = eligible.where((card) => card.isNew).take(newCardLimit);
    return [...due, ...fresh];
  }
}
