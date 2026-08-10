class BookChapterSummary {
  const BookChapterSummary({
    required this.id,
    required this.title,
    required this.chapterNumber,
    required this.description,
  });

  final int id;
  final String title;
  final int? chapterNumber;
  final String description;
}

class BookChapter {
  const BookChapter({
    required this.id,
    required this.title,
    required this.chapterNumber,
    required this.content,
  });

  final int id;
  final String title;
  final int? chapterNumber;
  final String content;
}
