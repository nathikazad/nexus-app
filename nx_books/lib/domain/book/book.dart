enum BookReadingState {
  reading('reading', 'Reading'),
  toRead('to_read', 'To Read'),
  read('read', 'Read');

  const BookReadingState(this.kgqlValue, this.label);

  final String kgqlValue;
  final String label;

  static BookReadingState fromKgql(Object? value) {
    final text = value?.toString().trim();
    for (final state in values) {
      if (state.kgqlValue == text) return state;
    }
    return BookReadingState.toRead;
  }
}

class NxBook {
  const NxBook({
    required this.id,
    required this.title,
    required this.description,
    required this.author,
    required this.link,
    required this.tags,
    required this.readingState,
    required this.rank,
    required this.totalChapters,
    required this.currentChapter,
    required this.wordCount,
    required this.updatedAt,
    required this.updatedLabel,
  });

  final int id;
  final String title;
  final String description;
  final String author;
  final String link;
  final List<String> tags;
  final BookReadingState readingState;
  final int? rank;
  final int? totalChapters;
  final int? currentChapter;
  final int wordCount;
  final DateTime updatedAt;
  final String updatedLabel;

  double? get progressFraction {
    final total = totalChapters;
    final current = currentChapter;
    if (total == null || current == null || total <= 0) return null;
    return current.clamp(0, total) / total;
  }

  int? get progressPercent {
    final fraction = progressFraction;
    if (fraction == null) return null;
    return (fraction * 100).round();
  }

  NxBook copyWith({
    String? title,
    String? description,
    String? author,
    String? link,
    List<String>? tags,
    BookReadingState? readingState,
    int? rank,
    bool clearRank = false,
    int? totalChapters,
    bool clearTotalChapters = false,
    int? currentChapter,
    bool clearCurrentChapter = false,
    int? wordCount,
    DateTime? updatedAt,
    String? updatedLabel,
  }) {
    return NxBook(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      author: author ?? this.author,
      link: link ?? this.link,
      tags: tags ?? this.tags,
      readingState: readingState ?? this.readingState,
      rank: clearRank ? null : rank ?? this.rank,
      totalChapters: clearTotalChapters
          ? null
          : totalChapters ?? this.totalChapters,
      currentChapter: clearCurrentChapter
          ? null
          : currentChapter ?? this.currentChapter,
      wordCount: wordCount ?? this.wordCount,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedLabel: updatedLabel ?? this.updatedLabel,
    );
  }
}

List<NxBook> sortedBooksForState(List<NxBook> books, BookReadingState state) {
  final rows = [
    for (final book in books)
      if (book.readingState == state) book,
  ];
  rows.sort(compareBooksInLane);
  return rows;
}

int compareBooksInLane(NxBook a, NxBook b) {
  final rank = (a.rank ?? 1 << 30).compareTo(b.rank ?? 1 << 30);
  if (rank != 0) return rank;
  final updated = b.updatedAt.compareTo(a.updatedAt);
  if (updated != 0) return updated;
  final title = a.title.toLowerCase().compareTo(b.title.toLowerCase());
  if (title != 0) return title;
  return a.id.compareTo(b.id);
}

Uri notesUriForBook(int bookId, Uri base) {
  final path = '/docs/$bookId';
  if (base.scheme == 'http' || base.scheme == 'https') {
    return Uri.parse('${base.scheme}://${base.authority}$path');
  }
  return Uri(path: path);
}
