import 'package:nx_cards/domain/card/cards_repository.dart';
import 'package:nx_cards/domain/cards_models.dart';

abstract interface class CardsWorkspace implements CardsRepository {
  Stream<CardsDashboard> watchDashboard();

  Future<void> syncLibrary();

  Future<void> syncDeck(int deckId);

  Future<void> close();
}
