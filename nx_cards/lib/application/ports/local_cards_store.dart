import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_offline/nx_offline.dart';

abstract interface class LocalCardsStore implements OutboxStore {
  Stream<CardsDashboard> watchDashboard();

  Future<CardsDashboard> readDashboard();

  Future<CardDeck?> getDeck(int deckId);

  Future<StudyCard?> getCard(int cardId);

  Future<List<StudyCard>> cardsForDeck(int deckId);

  Future<List<CardDeckManifestEntry>> deckManifest({Set<int>? deckIds});

  Future<void> applySyncBundle(CardDeckSyncBundle bundle);

  Future<void> applyCardSnapshot(List<StudyCard> cards);

  Future<void> saveCardAndEnqueue(
    StudyCard card, {
    required String operationId,
    required MutationType mutationType,
    required DateTime createdAt,
  });
}
