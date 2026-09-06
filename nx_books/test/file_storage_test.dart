import 'dart:io';
import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_books/data/offline/cached_document_repository.dart';
import 'package:nx_documents/nx_documents.dart';
import 'package:nx_offline/nx_offline_storage.dart';
import 'package:nx_offline/src/storage/content_files_native.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'legacy book content moves to a verified file and leaves preferences',
    () async {
      const identity = DocumentIdentity(id: 7, modelType: 'Book');
      const key = 'nx_books.offline.user.document.Book.7';
      SharedPreferences.setMockInitialValues({
        key: jsonEncode({
          'title': 'Book',
          'plainText': 'Offline body',
          'jsonDocument': {'nodes': []},
          'updatedAt': '2026-01-01T00:00:00Z',
        }),
      });
      final dir = await Directory.systemTemp.createTemp('nx-books-files-');
      final files = DirectoryContentFiles(Directory('${dir.path}/content'));
      final library = FileLibrary(
        database: LibraryDatabase(
          NativeDatabase(File('${dir.path}/index.sqlite')),
        ),
        files: files,
      );
      addTearDown(() async {
        await library.close();
        await dir.delete(recursive: true);
      });
      final repository = CachedDocumentContentRepository(
        remote: _OfflineRemote(),
        accountKey: 'user',
        library: library,
      );
      final content = await repository.load(identity);
      expect(content!.plainText, 'Offline body');
      expect((await SharedPreferences.getInstance()).containsKey(key), isFalse);
      final stored = (await library.metadata('Book', '7'))!;
      expect(isContentReference(stored.reference), isTrue);
      expect(stored.summary.toString(), isNot(contains('Offline body')));
      final before = files.reads;
      await repository.ensureCached(identity);
      expect(files.reads, before);
    },
  );
}

class _OfflineRemote implements DocumentContentRepository {
  @override
  Future<DocumentContent?> load(DocumentIdentity identity) async =>
      throw const SocketException('offline');
  @override
  Future<DocumentContent> save(DocumentContent content) async =>
      throw const SocketException('offline');
}
