import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_books/data/offline/books_library_sync.dart';
import 'package:nx_books/data/offline/cached_document_repository.dart';
import 'package:nx_documents/nx_documents.dart';
import 'package:nx_offline/nx_offline_storage.dart';
import 'package:nx_offline/src/storage/content_files_native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nx_books/data/offline/preferences_download_report_store.dart';
import 'package:nx_books/domain/book/download_report.dart';

void main() {
  test(
    'downloads unopened chapters, skips unchanged files and resumes failures',
    () async {
      SharedPreferences.setMockInitialValues({});
      final directory = await Directory.systemTemp.createTemp('books-sync-');
      final library = FileLibrary(
        database: LibraryDatabase(NativeDatabase.memory()),
        files: DirectoryContentFiles(directory),
      );
      addTearDown(() async {
        await library.close();
        await directory.delete(recursive: true);
      });
      final remote = _Remote();
      final revisions = {
        for (var id = 0; id < 45; id++)
          DocumentIdentity(id: id, modelType: id == 0 ? 'Book' : 'Document'):
              remote.revision,
      };
      final pull = BooksLibraryPull(
        reportStore: const PreferencesDownloadReportStore('test'),
        discover: () async => revisions,
        repository: CachedDocumentContentRepository(
          remote: remote,
          accountKey: 'test',
          library: library,
        ),
      );
      remote.failAt = 22;
      await expectLater(pull.pullAll(), throwsStateError);
      expect(await library.metadata('Document', '21'), isNotNull);
      expect(await library.metadata('Document', '23'), isNotNull);
      final partial = await const PreferencesDownloadReportStore('test').load();
      expect(partial?.verified, 44);
      expect(partial?.failed, ['Document/22']);
      expect(partial?.phase, DownloadPhase.incomplete);
      remote.failAt = null;
      remote.calls.clear();
      await pull.pullAll();
      expect(remote.calls, [22]);
      expect(await library.read('Document', '44'), contains('chapter 44'));
      remote.calls.clear();
      await pull.pullAll();
      expect(remote.calls, isEmpty);
      final complete = await const PreferencesDownloadReportStore(
        'test',
      ).load();
      expect(complete?.phase, DownloadPhase.complete);
      expect(complete?.verified, 45);
      remote.revision = DateTime.utc(2026, 9, 7);
      revisions[revisions.keys.last] = remote.revision;
      await pull.pullAll();
      expect(remote.calls, [44]);
      // Same-size corruption must not be counted as an offline-ready text.
      final metadata = (await library.metadata('Document', '44'))!;
      final path = ContentReference.decode(metadata.reference).path;
      final file = File('${directory.path}/$path');
      final original = await file.readAsString();
      await file.writeAsString(original.replaceAll('chapter 44', 'chapter zz'));
      await expectLater(pull.pullAll(), throwsStateError);
      final damaged = await const PreferencesDownloadReportStore('test').load();
      expect(damaged?.phase, DownloadPhase.incomplete);
      expect(damaged?.verified, 44);
      expect(damaged?.failed, ['Document/44']);
    },
  );
}

class _Remote implements DocumentContentRepository {
  DateTime revision = DateTime.utc(2026, 9, 6);
  int? failAt;
  final calls = <int>[];
  @override
  Future<DocumentContent?> load(DocumentIdentity identity) async {
    calls.add(identity.id);
    if (identity.id == failAt) throw StateError('offline');
    return DocumentContent(
      identity: identity,
      title: 'chapter ${identity.id}',
      plainText: 'chapter ${identity.id}',
      jsonDocument: {},
      updatedAt: revision,
    );
  }

  @override
  Future<DocumentContent> save(DocumentContent content) async => content;
}
