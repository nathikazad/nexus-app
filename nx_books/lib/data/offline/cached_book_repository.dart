import 'dart:convert';
import 'package:nx_offline/nx_offline_storage.dart';

import 'package:nx_books/domain/book/book.dart';
import 'package:nx_books/domain/book/book_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the last successful bookshelf response available for offline reading.
/// Mutations remain network-backed and are refreshed into this cache by the
/// providers after they complete.
final class CachedBookRepository implements BookRepository, BookCatalogRefresh {
  CachedBookRepository({
    required this.remote,
    required this.accountKey,
    this.library,
    this.cacheFirst = true,
  });

  final BookRepository remote;
  final String accountKey;
  final FileLibrary? library;
  final bool cacheFirst;
  bool _booksDirty = false;
  bool _tagsDirty = false;
  int _mutationRevision = 0;
  int get generation => _mutationRevision;

  String get _booksKey => 'nx_books.offline.$accountKey.books';
  String get _tagsKey => 'nx_books.offline.$accountKey.topic_tags';

  @override
  Future<List<NxBook>> listBooks() async {
    final cached = await _loadBooks();
    if (cacheFirst && cached != null && !_booksDirty) return cached;
    try {
      await refreshBooks();
      return await _loadBooks() ?? cached ?? const [];
    } catch (_) {
      if (cached != null) return cached;
      rethrow;
    }
  }

  @override
  Future<void> refreshBooks() async {
    final revision = _mutationRevision;
    final books = await remote.listBooks();
    if (revision != _mutationRevision) return;
    if (library != null) {
      await _storeBooks(books);
    } else {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _booksKey,
        jsonEncode(books.map(_bookToJson).toList()),
      );
    }
    if (revision == _mutationRevision) _booksDirty = false;
  }

  @override
  Future<List<String>> listTopicTags() async {
    final cached = await _loadTags();
    if (cacheFirst && cached != null && !_tagsDirty) return cached;
    try {
      await refreshTopicTags();
      return await _loadTags() ?? cached ?? const [];
    } catch (_) {
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<List<String>?> _loadTags() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_tagsKey);
    if (encoded == null) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return null;
      return [for (final tag in decoded) tag.toString()];
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> refreshTopicTags() async {
    final revision = _mutationRevision;
    final tags = await remote.listTopicTags();
    if (revision != _mutationRevision) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tagsKey, jsonEncode(tags));
    if (revision == _mutationRevision) _tagsDirty = false;
  }

  Future<T> _mutate<T>(
    Future<T> Function() mutation, {
    bool tags = false,
  }) async {
    _mutationRevision++;
    try {
      final result = await mutation();
      _booksDirty = true;
      if (tags) _tagsDirty = true;
      return result;
    } finally {
      _mutationRevision++;
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

  /// Publish a complete server manifest projection; transport stays outside
  /// this repository. Called only after all required snapshots are available.
  Future<void> cacheSyncedCatalog(
    List<NxBook> books,
    List<String> tags,
    int startedAt,
  ) async {
    if (startedAt != _mutationRevision) {
      throw StateError('Books changed during sync; retry after saving');
    }
    await _storeBooks(books);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tagsKey, jsonEncode(tags));
    if (startedAt != _mutationRevision) {
      throw StateError('Books changed during sync; retry after saving');
    }
    _booksDirty = false;
    _tagsDirty = false;
  }

  @override
  Future<NxBook> createBook({String? title}) =>
      _mutate(() => remote.createBook(title: title));

  @override
  Future<void> deleteBook(int id) => _mutate(() => remote.deleteBook(id));

  @override
  Future<void> updateBookRank({required int id, required int rank}) =>
      _mutate(() => remote.updateBookRank(id: id, rank: rank));

  @override
  Future<void> updateBookState({
    required int id,
    required BookReadingState state,
    required int rank,
  }) => _mutate(() => remote.updateBookState(id: id, state: state, rank: rank));

  @override
  Future<void> updateBookTopicTags({
    required int id,
    required List<String> tags,
  }) =>
      _mutate(() => remote.updateBookTopicTags(id: id, tags: tags), tags: true);
}

Map<String, dynamic> _bookToJson(NxBook book) => <String, dynamic>{
  'id': book.id,
  'title': book.title,
  'description': book.description,
  'author': book.author,
  'link': book.link,
  'bookLink': book.bookLink,
  'bookFileHash': book.bookFileHash,
  'bookFileSize': book.bookFileSize,
  'tags': book.tags,
  'readingState': book.readingState.kgqlValue,
  'rank': book.rank,
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
  bookLink: json['bookLink']?.toString() ?? '',
  bookFileHash: json['bookFileHash'] as String?,
  bookFileSize: (json['bookFileSize'] as num?)?.toInt(),
  tags: [for (final tag in json['tags'] as List? ?? const []) tag.toString()],
  readingState: BookReadingState.fromKgql(json['readingState']),
  rank: (json['rank'] as num?)?.toInt(),
  wordCount: (json['wordCount'] as num?)?.toInt() ?? 0,
  updatedAt:
      DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  updatedLabel: json['updatedLabel']?.toString() ?? '',
);
