import 'package:nx_cards/domain/cards_models.dart';

abstract interface class CardsSyncTransport {
  Future<CardMutationResult> mutateCard(
    StudyCard card, {
    required DateTime clientUpdatedAt,
  });

  Future<CardMutationResult> deleteCard(
    int cardId, {
    required DateTime clientUpdatedAt,
  });

  Future<CardMutationResult> createDeck({
    required String name,
    required String description,
    String? fromLanguage,
    String? toLanguage,
    required DateTime clientUpdatedAt,
  });

  Future<CardMutationResult> createCard({
    required CardContent content,
    int? deckId,
    int? sourceBookId,
    required DateTime clientUpdatedAt,
  });

  Future<List<StudyCard>> syncCards();

  Future<CardDeckSyncBundle> syncDecks({
    required List<CardDeckManifestEntry> manifest,
    Set<int>? deckIds,
  });
}
