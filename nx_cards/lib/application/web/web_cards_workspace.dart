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
    return CardsDashboard(cards: await _repository.listCards());
  }

  @override
  Future<List<StudyCard>> listCards() => _repository.listCards();
  @override
  Future<List<String>> listLanguages() => _repository.listLanguages();
  @override
  Future<List<RelatedBook>> listBooks() => _repository.listBooks();
  @override
  Future<void> addLanguage(String name) => _repository.addLanguage(name);
  @override
  Future<int> createCard({required CardContent content, int? sourceBookId}) =>
      _repository.createCard(content: content, sourceBookId: sourceBookId);
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
  Future<void> setLearningStatus(StudyCard card, LearningStatus status) =>
      _repository.setLearningStatus(card, status);
  @override
  Future<void> deleteCard(int id) => _repository.deleteCard(id);
  @override
  Future<void> syncLibrary() async {}
  @override
  Future<void> close() async {}
}
