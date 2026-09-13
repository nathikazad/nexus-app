import '../remote/cards_sync_transport.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_offline/nx_offline.dart';

abstract interface class LocalCardsStore implements OutboxStore {
  Stream<CardsDashboard> watchDashboard();

  Future<CardsDashboard> readDashboard();

  Future<StudyCard?> getCard(int cardId);

  Future<void> applyCardSnapshot(List<StudyCard> cards);

  Future<void> saveCardAndEnqueue(
    StudyCard card, {
    required String operationId,
    required MutationType mutationType,
    required DateTime createdAt,
  });
}

abstract interface class QueuedCardReader {
  Future<StudyCard?> readQueuedCard(int cardId, String reference);
}

abstract interface class HashCardsStore {
  int get editGeneration;
  Future<bool> verifiedCard(CardHash entry);
  Future<List<int>> applyCardBatch(
    List<HashedCard> cards, {
    int? expectedGeneration,
  });
  Future<void> publishCardManifest(
    List<CardHash> manifest, {
    int? expectedGeneration,
  });
}
