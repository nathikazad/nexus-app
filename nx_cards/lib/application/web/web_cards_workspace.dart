import 'package:nx_cards/application/cards_workspace.dart';
import 'package:nx_cards/domain/card/cards_repository.dart';
import 'package:nx_cards/domain/cards_models.dart';

final class WebCardsWorkspace implements CardsWorkspace {
  const WebCardsWorkspace(this._repository);

  final CardsRepository _repository;

  @override
  Stream<CardsDashboard> watchDashboard() =>
      Stream<CardsDashboard>.fromFuture(_dashboard());

  Future<CardsDashboard> _dashboard() async {
    final values = await Future.wait(<Future<Object>>[
      _repository.listDecks(),
      _repository.listCards(),
    ]);
    return CardsDashboard(
      decks: values[0] as List<CardDeck>,
      cards: values[1] as List<StudyCard>,
    );
  }

  @override
  Future<List<CardDeck>> listDecks() => _repository.listDecks();
  @override
  Future<List<StudyCard>> listCards() => _repository.listCards();
  @override
  Future<List<String>> listLanguages() => _repository.listLanguages();
  @override
  Future<List<RelatedBook>> listBooks() => _repository.listBooks();
  @override
  Future<void> addLanguage(String name) => _repository.addLanguage(name);
  @override
  Future<int> createDeck({
    required String name,
    required String description,
    String? fromLanguage,
    String? toLanguage,
  }) => _repository.createDeck(
    name: name,
    description: description,
    fromLanguage: fromLanguage,
    toLanguage: toLanguage,
  );
  @override
  Future<int> createCard({
    required CardContent content,
    required int deckId,
    int? sourceBookId,
  }) => _repository.createCard(
    content: content,
    deckId: deckId,
    sourceBookId: sourceBookId,
  );
  @override
  Future<void> updateCardContent({
    required int id,
    required CardContent content,
  }) => _repository.updateCardContent(id: id, content: content);
  @override
  Future<void> saveSchedule(StudyCard card) => _repository.saveSchedule(card);
  @override
  Future<void> setSuspended(StudyCard card, bool suspended) =>
      _repository.setSuspended(card, suspended);
  @override
  Future<void> deleteCard(int id) => _repository.deleteCard(id);
  @override
  Future<void> syncLibrary() async {}
  @override
  Future<void> syncDeck(int deckId) async {}
  @override
  Future<void> close() async {}
}
