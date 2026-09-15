import 'card.dart';
import 'collection.dart';
import 'study.dart';
import 'study_card.dart';

final class LibrarySource {
  const LibrarySource({
    required this.kind,
    required this.id,
    required this.name,
    required this.total,
    required this.current,
    required this.due,
  });
  final String kind, id, name;
  final int total, current, due;
  factory LibrarySource.fromJson(Map json) => LibrarySource(
    kind: json['kind'] as String,
    id: json['id'].toString(),
    name: json['name'] as String,
    total: json['total'] as int,
    current: json['current'] as int,
    due: json['due'] as int,
  );
}

List<LibrarySource> summarizeLibrary(CardsDashboard data) {
  final now = DateTime.now();
  final books = <int, String>{
    for (final card in data.cards)
      if (card.sourceBookId != null)
        card.sourceBookId!: card.sourceBookName ?? 'Book',
  };
  int current(List<StudyCard> cards) =>
      cards.where((c) => c.learningStatus == LearningStatus.learning).length;
  return [
    for (final language in data.languages)
      LibrarySource(
        kind: 'language',
        id: language,
        name: language,
        total: data.cardsForLanguage(language).length,
        current: current(data.cardsForLanguage(language)),
        due: data.dueCount(now, language: language, cue: StudyCue.fromLanguage),
      ),
    for (final book in books.entries)
      LibrarySource(
        kind: 'book',
        id: '${book.key}',
        name: book.value,
        total: data.cardsForBook(book.key).length,
        current: current(data.cardsForBook(book.key)),
        due: data.dueCount(now, bookId: book.key),
      ),
  ];
}
