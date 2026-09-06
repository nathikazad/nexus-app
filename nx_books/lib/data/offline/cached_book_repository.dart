import 'dart:convert';
import 'package:nx_offline/nx_offline_storage.dart';

import 'package:nx_books/domain/book/book.dart';
import 'package:nx_books/domain/book/book_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the last successful bookshelf response available for offline reading.
/// Mutations remain network-backed and are refreshed into this cache by the
/// providers after they complete.
final class CachedBookRepository implements BookRepository {
  CachedBookRepository({
    required this.remote,
    required this.accountKey,
    this.library,
  });

  final BookRepository remote;
  final String accountKey;
  final FileLibrary? library;

  String get _booksKey => 'nx_books.offline.$accountKey.books';
  String get _tagsKey => 'nx_books.offline.$accountKey.topic_tags';

  @override
  Future<List<NxBook>> listBooks() async {
    try {
      final books = await remote.listBooks();
      final storage = library;
      if (storage != null) {
        await _storeBooks(books);
      } else {
        final preferences = await SharedPreferences.getInstance();
        await preferences.setString(
          _booksKey,
          jsonEncode(books.map(_bookToJson).toList()),
        );
      }
      return books;
    } catch (_) {
      final cached = await _loadBooks();
      if (cached != null) return cached;
      rethrow;
    }
  }

  @override
  Future<List<String>> listTopicTags() async {
    try {
      final tags = await remote.listTopicTags();
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_tagsKey, jsonEncode(tags));
      return tags;
    } catch (_) {
      final preferences = await SharedPreferences.getInstance();
      final encoded = preferences.getString(_tagsKey);
      if (encoded == null) rethrow;
      final decoded = jsonDecode(encoded);
      if (decoded is! List) rethrow;
      return [for (final tag in decoded) tag.toString()];
    }
  }

  Future<List<NxBook>?> _loadBooks() async {
    final storage = library;
    if (storage != null) {
      if (await storage.hasCatalog('books')) {
        final books = <NxBook>[];
        var offset = 0;
        while (true) {
          final page = await storage.catalog('books', offset: offset);
          for (final row in page) {
            books.add(_bookFromJson(Map<String, dynamic>.from(row.summary)));
          }
          if (page.length < 50) break;
          offset += page.length;
        }
        return books;
      }
    }
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_booksKey);
    if (encoded == null) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return null;
      final books = [
        for (final row in decoded)
          if (row is Map) _bookFromJson(Map<String, dynamic>.from(row)),
      ];
      if (storage != null) {
        await _storeBooks(books);
        await preferences.remove(_booksKey);
      }
      return books;
    } catch (_) {
      return null;
    }
  }

  Future<void> _storeBooks(List<NxBook> books) =>
      library!.replaceCatalog('books', [
        for (final book in books)
          LibraryRecord(
            collection: 'bookshelf',
            id: '${book.id}',
            content: jsonEncode(_bookToJson(book)),
            summary: _bookToJson(book),
          ),
      ]);

  @override
  Future<NxBook> createBook({String? title}) => remote.createBook(title: title);

  @override
  Future<void> deleteBook(int id) => remote.deleteBook(id);

  @override
  Future<void> updateBookChapterProgress({
    required int id,
    required int? totalChapters,
    required int? currentChapter,
  }) => remote.updateBookChapterProgress(
    id: id,
    totalChapters: totalChapters,
    currentChapter: currentChapter,
  );

  @override
  Future<void> updateBookRank({required int id, required int rank}) =>
      remote.updateBookRank(id: id, rank: rank);

  @override
  Future<void> updateBookState({
    required int id,
    required BookReadingState state,
    required int rank,
  }) => remote.updateBookState(id: id, state: state, rank: rank);

  @override
  Future<void> updateBookTopicTags({
    required int id,
    required List<String> tags,
  }) => remote.updateBookTopicTags(id: id, tags: tags);
}

Map<String, dynamic> _bookToJson(NxBook book) => <String, dynamic>{
  'id': book.id,
  'title': book.title,
  'description': book.description,
  'author': book.author,
  'link': book.link,
  'tags': book.tags,
  'readingState': book.readingState.kgqlValue,
  'rank': book.rank,
  'totalChapters': book.totalChapters,
  'currentChapter': book.currentChapter,
  'wordCount': book.wordCount,
  'updatedAt': book.updatedAt.toUtc().toIso8601String(),
  'updatedLabel': book.updatedLabel,
};

NxBook _bookFromJson(Map<String, dynamic> json) => NxBook(
  id: (json['id'] as num).toInt(),
  title: json['title']?.toString() ?? '',
  description: json['description']?.toString() ?? '',
  author: json['author']?.toString() ?? '',
  link: json['link']?.toString() ?? '',
  tags: [for (final tag in json['tags'] as List? ?? const []) tag.toString()],
  readingState: BookReadingState.fromKgql(json['readingState']),
  rank: (json['rank'] as num?)?.toInt(),
  totalChapters: (json['totalChapters'] as num?)?.toInt(),
  currentChapter: (json['currentChapter'] as num?)?.toInt(),
  wordCount: (json['wordCount'] as num?)?.toInt() ?? 0,
  updatedAt:
      DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  updatedLabel: json['updatedLabel']?.toString() ?? '',
);
