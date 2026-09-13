import 'package:nx_cards/browser/browser.dart';

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

final class CardHash {
  const CardHash(this.id, this.hash);
  final int id;
  final String hash;
}

final class HashedCard {
  const HashedCard(this.card, this.hash);
  final StudyCard card;
  final String hash;
}

final class CardHashBundle {
  const CardHashBundle(this.manifest, this.cards, this.deletedIds);
  final List<CardHash> manifest;
  final List<HashedCard> cards;
  final Set<int> deletedIds;
}

abstract interface class HashCardsSyncTransport {
  Future<CardHashBundle> cardManifest();
  Future<CardHashBundle> downloadCards(Set<int> ids);
}
