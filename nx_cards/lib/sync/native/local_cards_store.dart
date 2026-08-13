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
