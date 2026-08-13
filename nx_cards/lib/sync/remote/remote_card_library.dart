import 'package:nx_cards/browser/browser.dart';

final class RemoteCardLibrary implements CardWorkspace {
  const RemoteCardLibrary(this._repository);

  final CardLibrary _repository;

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
