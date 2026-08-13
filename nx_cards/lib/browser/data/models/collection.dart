import 'package:nx_cards/browser/data/models/card.dart';
import 'package:nx_cards/browser/data/models/study.dart';
import 'package:nx_cards/browser/data/models/study_card.dart';

class RelatedBook {
  const RelatedBook(this.id, this.name);

  final int id;
  final String name;
}

/// Persistence-neutral interface to the person's card library.
abstract interface class CardLibrary {
  Future<List<StudyCard>> listCards();
  Future<List<String>> listLanguages();
  Future<List<RelatedBook>> listBooks();
  Future<void> addLanguage(String name);

  Future<int> createCard({required CardContent content, int? sourceBookId});

  Future<void> updateCardContent({
    required int id,
    required CardContent content,
  });

  Future<void> saveSchedule(StudyCard card);
  Future<void> setSuspended(StudyCard card, bool suspended);
  Future<void> setLearningStatus(StudyCard card, LearningStatus status);
  Future<void> deleteCard(int id);
}

abstract interface class CardWorkspace implements CardLibrary {
  Stream<CardsDashboard> watchDashboard();

  Future<void> syncLibrary();

  Future<void> close();
}

class CardsDashboard {
  const CardsDashboard({required this.cards});

  final List<StudyCard> cards;

  String? languageFor(StudyCard card) => card.language;

  List<String> get languages => <String>{
    for (final card in cards)
      if (languageFor(card) case final language? when language.isNotEmpty)
        language,
  }.toList()..sort((left, right) => left.compareTo(right));

  List<StudyCard> cardsForLanguage(String language) => cards
      .where((card) => languageFor(card) == language)
      .toList(growable: false);

  List<StudyCard> cardsForBook(int bookId) => cards
      .where((card) => card.sourceBookId == bookId)
      .toList(growable: false);

  Iterable<StudyPrompt> _prompts({
    String? studyCategory,
    String? language,
    int? bookId,
  }) => cards
      .where(
        (card) =>
            (studyCategory == null ||
                card.belongsToStudyCategory(studyCategory)) &&
            (language == null || languageFor(card) == language) &&
            (bookId == null || card.sourceBookId == bookId) &&
            !card.isPhraseCard &&
            (card.studyCategories.isEmpty || card.isRecallEligible),
      )
      .expand((card) => card.prompts);

  int dueCount(
    DateTime now, {
    String? studyCategory,
    String? language,
    int? bookId,
  }) =>
      _prompts(studyCategory: studyCategory, language: language, bookId: bookId)
          .where((prompt) => prompt.isDueAt(now))
          .map((prompt) => prompt.cardId)
          .toSet()
          .length;

  int newCount({String? studyCategory, String? language, int? bookId}) =>
      _prompts(studyCategory: studyCategory, language: language, bookId: bookId)
          .where((prompt) => prompt.isNew)
          .map((prompt) => prompt.cardId)
          .toSet()
          .length;

  List<StudyPrompt> studyQueue(
    DateTime now, {
    int newCardLimit = 20,
    String? studyCategory,
    String? language,
    int? bookId,
  }) {
    final eligible = _prompts(
      studyCategory: studyCategory,
      language: language,
      bookId: bookId,
    );
    final due = eligible.where((prompt) => prompt.isDueAt(now)).toList()
      ..sort(
        (a, b) => (a.schedule.dueAt ?? now).compareTo(b.schedule.dueAt ?? now),
      );
    final fresh =
        eligible.where((prompt) => prompt.isNew).take(newCardLimit).toList()
          ..sort((a, b) {
            final cue = a.cue.index.compareTo(b.cue.index);
            return cue != 0 ? cue : a.cardId.compareTo(b.cardId);
          });
    return _separateSiblingPrompts(<StudyPrompt>[...due, ...fresh]);
  }
}

List<StudyPrompt> _separateSiblingPrompts(List<StudyPrompt> source) {
  final remaining = [...source];
  final result = <StudyPrompt>[];
  while (remaining.isNotEmpty) {
    var index = 0;
    if (result.isNotEmpty) {
      final alternative = remaining.indexWhere(
        (prompt) => prompt.cardId != result.last.cardId,
      );
      if (alternative >= 0) index = alternative;
    }
    result.add(remaining.removeAt(index));
  }
  return result;
}
