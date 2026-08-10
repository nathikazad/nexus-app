import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_notes/domain/book/book_chapter.dart';
import 'package:nx_notes/domain/book/book_chapter_repository.dart';

const kBookModelTypeName = 'Book';
const kBookChapterModelTypeName = 'Book Chapter';
const kBookChapterNumberAttribute = 'chapter_number';

final class KgqlBookChapterRepository implements BookChapterRepository {
  KgqlBookChapterRepository(this._client);

  final GraphQLClient _client;
  final Map<int, List<BookChapterSummary>> _summariesByBook = {};
  final Map<int, BookChapter> _chaptersById = {};

  @override
  Future<List<BookChapterSummary>> listChapters(int bookId) async {
    final cached = _summariesByBook[bookId];
    if (cached != null) return cached;

    final book = await fetchKgqlModelById(
      _client,
      modelTypeName: kBookModelTypeName,
      id: bookId,
      struct: const <String, dynamic>{
        'id': true,
        'name': true,
        kBookChapterModelTypeName: <String, dynamic>{
          'id': true,
          'name': true,
          'description': true,
          kBookChapterNumberAttribute: true,
        },
      },
    );
    if (book == null) {
      throw StateError('Book $bookId was not found.');
    }

    final chapters = <BookChapterSummary>[
      for (final model
          in book.relations?[kBookChapterModelTypeName] ?? const <Model>[])
        BookChapterSummary(
          id: model.id,
          title: model.name,
          chapterNumber: model.attrInt(kBookChapterNumberAttribute),
          description: model.description?.trim() ?? '',
        ),
    ]..sort(_compareChapterSummaries);
    final immutable = List<BookChapterSummary>.unmodifiable(chapters);
    _summariesByBook[bookId] = immutable;
    return immutable;
  }

  @override
  Future<List<BookChapter>> loadSelectedChapters({
    required int bookId,
    required Set<int> chapterIds,
  }) async {
    if (chapterIds.isEmpty) return const <BookChapter>[];
    final summaries = await listChapters(bookId);
    final selected = [
      for (final summary in summaries)
        if (chapterIds.contains(summary.id)) summary,
    ];
    if (selected.length != chapterIds.length) {
      throw StateError(
        'One or more selected chapters do not belong to this book.',
      );
    }

    final loaded = await Future.wait(<Future<BookChapter>>[
      for (final summary in selected) _loadChapter(summary),
    ]);
    return List<BookChapter>.unmodifiable(loaded);
  }

  Future<BookChapter> _loadChapter(BookChapterSummary summary) async {
    final cached = _chaptersById[summary.id];
    if (cached != null) return cached;
    final model = await fetchKgqlModelById(
      _client,
      modelTypeName: kBookChapterModelTypeName,
      id: summary.id,
      struct: const <String, dynamic>{
        'id': true,
        'name': true,
        kBookChapterNumberAttribute: true,
        'document': true,
      },
    );
    if (model == null) {
      throw StateError('Book chapter ${summary.id} was not found.');
    }
    final chapter = BookChapter(
      id: model.id,
      title: model.name,
      chapterNumber: model.attrInt(kBookChapterNumberAttribute),
      content: model.attrString('document')?.trim() ?? '',
    );
    _chaptersById[chapter.id] = chapter;
    return chapter;
  }
}

int _compareChapterSummaries(
  BookChapterSummary left,
  BookChapterSummary right,
) {
  final leftNumber = left.chapterNumber;
  final rightNumber = right.chapterNumber;
  if (leftNumber != null && rightNumber != null) {
    final byNumber = leftNumber.compareTo(rightNumber);
    if (byNumber != 0) return byNumber;
  } else if (leftNumber != null) {
    return -1;
  } else if (rightNumber != null) {
    return 1;
  }
  final byTitle = left.title.compareTo(right.title);
  return byTitle != 0 ? byTitle : left.id.compareTo(right.id);
}
