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

  Future<CardMutationResult> createCard({
    required CardContent content,
    int? sourceBookId,
    required DateTime clientUpdatedAt,
  });

  Future<List<StudyCard>> syncCards();
}
