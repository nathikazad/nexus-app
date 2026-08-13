import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/domain/cards_models.dart';

void main() {
  final now = DateTime.utc(2026, 8, 3, 12);
  const deck = CardDeck(
    id: 1,
    name: 'French',
    description: '',
    fromLanguage: 'English',
    toLanguage: 'French',
    archived: false,
  );

  test('study queue places due cards before limited new cards', () {
    final dashboard = CardsDashboard(
      decks: const [deck],
      cards: [
        _card(1, dueAt: now.subtract(const Duration(days: 1)), reviewed: now),
        _card(2),
        _card(3),
        _card(4, dueAt: now.add(const Duration(days: 1)), reviewed: now),
      ],
    );

    final queue = dashboard.studyQueue(now, newCardLimit: 1);

    expect(queue.map((prompt) => prompt.cardId), [1, 2]);
    expect(dashboard.dueCount(now), 1);
    expect(dashboard.newCount(), 2);
  });

  test('suspended cards never enter the queue', () {
    final dashboard = CardsDashboard(
      decks: const [deck],
      cards: [_card(1, suspended: true)],
    );

    expect(dashboard.studyQueue(now), isEmpty);
  });

  test('each enabled cue has independent queue eligibility', () {
    final dashboard = CardsDashboard(
      decks: const [deck],
      cards: [_card(1, enableAllCues: true)],
    );

    final queue = dashboard.studyQueue(now);

    expect(queue, hasLength(3));
    expect(queue.map((prompt) => prompt.cue), StudyCue.values);
    expect(dashboard.newCount(), 1);
    expect(dashboard.cardCount(1), 1);
  });

  test('new language cues are mixed without adjacent siblings', () {
    final dashboard = CardsDashboard(
      decks: const [deck],
      cards: [
        _card(1, enableAllCues: true),
        _card(2, enableAllCues: true),
        _card(3, enableAllCues: true),
      ],
    );

    final queue = dashboard.studyQueue(now);

    expect(queue, hasLength(9));
    for (var index = 1; index < queue.length; index++) {
      expect(queue[index].cardId, isNot(queue[index - 1].cardId));
    }
    expect(queue.map((prompt) => prompt.cue).toSet(), StudyCue.values.toSet());
  });

  test('word queues include learning and learnt but not unstarted words', () {
    final dashboard = CardsDashboard(
      decks: const [deck],
      cards: [
        _card(
          1,
          modelTypeName: 'Word',
          wordCategory: 'Noun',
          learningStatus: LearningStatus.learning,
        ),
        _card(2, modelTypeName: 'Word', wordCategory: 'Noun'),
        _card(
          5,
          modelTypeName: 'Word',
          wordCategory: 'Noun',
          learningStatus: LearningStatus.learnt,
        ),
        _card(
          3,
          modelTypeName: 'Verb',
          learningStatus: LearningStatus.learning,
        ),
        _card(4, modelTypeName: 'Phrase'),
      ],
    );

    expect(
      dashboard
          .studyQueue(now, studyCategory: 'Noun')
          .map((prompt) => prompt.cardId),
      [1, 5],
    );
    expect(dashboard.newCount(studyCategory: 'Noun'), 2);
    expect(dashboard.studyQueue(now).map((prompt) => prompt.cardId), [1, 3, 5]);
  });

  test('groups cards by Language tag and Book relation without decks', () {
    final malayalam = _card(1, language: 'Malayalam');
    final spanish = _card(2, language: 'Spanish');
    final book = _card(3, deckId: 0, bookId: 4195, bookName: 'Four Steps');
    final dashboard = CardsDashboard(
      decks: const [deck],
      cards: [malayalam, spanish, book],
    );

    expect(dashboard.languages, ['Malayalam', 'Spanish']);
    expect(dashboard.cardsForLanguage('Malayalam'), [malayalam]);
    expect(dashboard.cardsForBook(4195), [book]);
    expect(
      dashboard.studyQueue(now, bookId: 4195).map((prompt) => prompt.cardId),
      [3],
    );
  });

  test('exposes every Word category and a category for untagged Verbs', () {
    final word = _card(
      1,
      modelTypeName: 'Word',
      wordCategories: const ['Noun', 'Adjective'],
    );
    final verb = _card(2, modelTypeName: 'Verb');

    expect(word.studyCategories, ['Noun', 'Adjective']);
    expect(word.belongsToStudyCategory('Adjective'), isTrue);
    expect(verb.studyCategories, ['Verb']);
  });
}

StudyCard _card(
  int id, {
  DateTime? dueAt,
  DateTime? reviewed,
  bool suspended = false,
  bool enableAllCues = false,
  LearningStatus learningStatus = LearningStatus.notStarted,
  String? modelTypeName,
  String? wordCategory,
  List<String>? wordCategories,
  String? language,
  int deckId = 1,
  int? bookId,
  String? bookName,
}) {
  return StudyCard(
    id: id,
    content: LanguageCardContent(
      english: 'front $id',
      originalScript: 'back $id',
      transliteration: 'sound $id',
    ),
    deckId: deckId,
    deckName: deckId == 0 ? '' : 'French',
    schedules: <StudyCue, CardSchedule>{
      StudyCue.fromLanguage: CardSchedule(
        enabled: true,
        dueAt: dueAt,
        lastReviewedAt: reviewed,
        stability: reviewed == null ? null : 1,
        difficulty: reviewed == null ? null : 5,
        schedulingState: reviewed == null ? 'learning' : 'review',
        learningStep: reviewed == null ? 0 : null,
        reviewCount: reviewed == null ? 0 : 1,
        lapseCount: 0,
      ),
      StudyCue.toLanguage: CardSchedule.initial(enabled: enableAllCues),
      StudyCue.transliteration: CardSchedule.initial(enabled: enableAllCues),
    },
    reviewHistory: const <StudyCue, List<CardReview>>{
      StudyCue.fromLanguage: <CardReview>[],
      StudyCue.toLanguage: <CardReview>[],
      StudyCue.transliteration: <CardReview>[],
    },
    suspended: suspended,
    learningStatus: learningStatus,
    modelTypeName: modelTypeName,
    tags: _tags(
      wordCategories: wordCategories,
      wordCategory: wordCategory,
      language: language,
    ),
    sourceBookId: bookId,
    sourceBookName: bookName,
  );
}

Map<String, List<String>> _tags({
  List<String>? wordCategories,
  String? wordCategory,
  String? language,
}) {
  final tags = <String, List<String>>{};
  final categories =
      wordCategories ?? (wordCategory == null ? null : <String>[wordCategory]);
  if (categories != null) tags['Word Category'] = categories;
  if (language != null) tags['Language'] = <String>[language];
  return tags;
}
