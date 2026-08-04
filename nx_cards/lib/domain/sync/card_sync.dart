import 'package:nx_cards/domain/card/study_card.dart';
import 'package:nx_cards/domain/deck/card_deck.dart';

enum CardLocalSyncState { synced, queued, retryWaiting, blocked }

final class CardDeckManifestEntry {
  const CardDeckManifestEntry({required this.deckId, this.serverHash});

  final int deckId;
  final String? serverHash;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': deckId,
    'hash': serverHash,
  };
}

final class RemoteCardDeck {
  const RemoteCardDeck({
    required this.deck,
    required this.cards,
    required this.serverHash,
  });

  final CardDeck deck;
  final List<StudyCard> cards;
  final String serverHash;
}

final class CardDeckSyncBundle {
  const CardDeckSyncBundle({required this.decks, required this.deletedDeckIds});

  const CardDeckSyncBundle.empty()
    : decks = const <RemoteCardDeck>[],
      deletedDeckIds = const <int>[];

  final List<RemoteCardDeck> decks;
  final List<int> deletedDeckIds;
}

enum CardMutationStatus { applied, stale, deleted }

final class DeckHashRevision {
  const DeckHashRevision({required this.deckId, required this.serverHash});

  final int deckId;
  final String serverHash;
}

final class CardMutationResult {
  const CardMutationResult({
    required this.status,
    required this.entityId,
    required this.deckHashes,
    required this.deletedDeckIds,
    this.updatedAt,
  });

  final CardMutationStatus status;
  final int entityId;
  final DateTime? updatedAt;
  final List<DeckHashRevision> deckHashes;
  final List<int> deletedDeckIds;
}
