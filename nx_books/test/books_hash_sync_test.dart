import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_books/data/offline/books_hash_sync.dart';
import 'package:nx_books/data/offline/books_sync_store.dart';
import 'package:nx_books/data/offline/cached_book_repository.dart';
import 'package:nx_books/data/offline/cached_document_repository.dart';
import 'package:nx_books/data/offline/reading_history_store.dart';
import 'package:nx_books/data/offline/preferences_download_report_store.dart';
import 'package:nx_books/domain/book/book_repository.dart';
import 'package:nx_books/domain/book/download_report.dart';
import 'package:nx_books/domain/book/reading_history.dart';
import 'package:nx_db/documents.dart';
import 'package:nx_documents/nx_documents.dart';
import 'package:nx_offline/nx_offline_storage.dart';
import 'package:nx_offline/src/storage/content_files_native.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory directory;
  late FileLibrary library;
  late BooksSyncStore store;
  late _Transport transport;
  late BooksHashPull pull;
  const report = PreferencesDownloadReportStore('hash-test');
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('books-hash-test-');
    library = FileLibrary(
      database: LibraryDatabase(NativeDatabase.memory()),
      files: DirectoryContentFiles(directory),
    );
    store = BooksSyncStore(
      library,
      CachedDocumentContentRepository(
        remote: _NoDocuments(),
        accountKey: 'test',
        library: library,
      ),
      ReadingHistoryStore(library),
      CachedBookRepository(
        remote: _NoBooks(),
        accountKey: 'test',
        library: library,
      ),
    );
    transport = _Transport();
    pull = BooksHashPull(
      transport: transport,
      store: store,
      reportStore: report,
    );
  });
  tearDown(() async {
    await library.close();
    await directory.delete(recursive: true);
  });

  test(
    'one manifest plus one batch initially; only one call when unchanged',
    () async {
      await pull.pullAll();
      expect(transport.manifestCalls, 1);
      expect(transport.downloads, [
        {1, 2},
      ]);
      expect((await store.catalog.listBooks()).single.title, 'Book 1');
      await pull.pullAll();
      expect(transport.manifestCalls, 2);
      expect(transport.downloads.length, 1);
      expect((await report.load())?.phase, DownloadPhase.complete);
      expect((await report.load())?.verified, 2);
    },
  );

  test('820 items still use one batch, not 820 download requests', () async {
    transport.entries
      ..clear()
      ..addEntries([
        for (var id = 1; id <= 820; id++) MapEntry(id, _entry(id, 'hash-$id')),
      ]);
    await pull.pullAll();
    expect(transport.downloads.single.length, 820);
    await pull.pullAll();
    expect(transport.manifestCalls, 2);
    expect(transport.downloads.length, 1);
    expect((await report.load())?.verified, 820);
  });

  test('progress does not republish the bookshelf', () async {
    var progress = 0;
    var published = 0;
    final observed = BooksHashPull(
      transport: transport,
      store: store,
      reportStore: report,
      onChanged: () => progress++,
      onCatalogChanged: () => published++,
    );
    await observed.pullAll();
    expect(progress, greaterThan(1));
    expect(published, 1);
    expect((await report.load())!.phase, DownloadPhase.complete);
  });

  test('chat-only hash change downloads only its parent', () async {
    await pull.pullAll();
    transport.entries[2] = _entry(2, 'changed', message: 'new answer');
    await pull.pullAll();
    expect(transport.downloads.last, {2});
    final history = await store.histories.load(
      const DocumentIdentity(id: 2, modelType: 'Document'),
    );
    expect(history!.messages.single.text, 'new answer');
    await pull.pullAll();
    expect(transport.downloads.length, 2);
  });

  test(
    'same-size local corruption is repaired despite a matching server hash',
    () async {
      await pull.pullAll();
      final item = (await library.metadata('Document', '2'))!;
      final file = File(
        '${directory.path}/${ContentReference.decode(item.reference).path}',
      );
      final raw = await file.readAsString();
      await file.writeAsString(raw.replaceAll('body', 'oops'));
      await pull.pullAll();
      expect(transport.downloads.last, {2});
      expect(await file.readAsString(), raw);
    },
  );

  test(
    'corrupt conversation is repaired even if the same snapshot was saved before',
    () async {
      await pull.pullAll();
      final item = (await library.metadata('reading_history', 'Document_2'))!;
      final file = File(
        '${directory.path}/${ContentReference.decode(item.reference).path}',
      );
      await file.writeAsString('broken');
      await pull.pullAll();
      expect(transport.downloads.last, {2});
      expect(
        await store.histories.load(
          const DocumentIdentity(id: 2, modelType: 'Document'),
        ),
        isNotNull,
      );
    },
  );

  test('deleted documents disappear without a body request', () async {
    await pull.pullAll();
    transport.entries.remove(1);
    await pull.pullAll();
    expect(await store.catalog.listBooks(), isEmpty);
    expect(await library.read('Book', '1'), isNull);
    expect(transport.downloads.length, 1);
  });

  test(
    'incomplete batch cannot publish completion and retries only missing item',
    () async {
      transport.omit = 2;
      await expectLater(pull.pullAll(), throwsStateError);
      expect((await report.load())?.phase, DownloadPhase.incomplete);
      transport.omit = null;
      await pull.pullAll();
      expect(transport.downloads.last, {2});
    },
  );

  test(
    'live chat changes are preserved and not acknowledged as synchronized',
    () async {
      await pull.pullAll();
      transport.entries[2] = _entry(2, 'new');
      transport.beforeDownload = () => store.histories.save(
        const DocumentIdentity(id: 2, modelType: 'Document'),
        ReadingHistory('Document 2', [
          ReadingMessage('assistant', 'live answer'),
        ]),
      );
      await expectLater(pull.pullAll(), throwsStateError);
      final history = await store.histories.load(
        const DocumentIdentity(id: 2, modelType: 'Document'),
      );
      expect(history!.messages.single.text, 'live answer');
    },
  );
}

DocumentSyncEntry _entry(int id, String hash, {String? message}) =>
    DocumentSyncEntry(
      documentId: id,
      syncHash: hash,
      document: {
        'id': id,
        'name': id == 1 ? 'Book 1' : 'Document 2',
        'model_type': {'id': id, 'name': id == 1 ? 'Book' : 'BookChapter'},
        'updated_at': '2026-09-11T00:00:00Z',
        'tags': {
          'Topic': ['Strategy'],
        },
        'attributes': {
          'document': 'body',
          'json_document': {
            'document': {'type': 'page', 'children': []},
          },
        },
        'relations': [],
        'transcripts': [
          if (message != null)
            {
              'id': 10,
              'messages': {
                '2026-09-11T00:00:00': {'sender': 'Agent', 'message': message},
              },
            },
        ],
      },
    );

class _Transport implements BooksSyncTransport {
  final entries = {1: _entry(1, 'a'), 2: _entry(2, 'b')};
  int manifestCalls = 0;
  int? omit;
  Future<void> Function()? beforeDownload;
  final downloads = <Set<int>>[];
  @override
  Future<DocumentSyncResponse> manifest() async {
    manifestCalls++;
    return DocumentSyncResponse(
      documents: [],
      deletedIds: [],
      topicTags: ['Strategy'],
      manifest: [
        for (final e in entries.values)
          DocumentHashEntry(
            e.documentId,
            (e.document['model_type'] as Map)['name'] as String,
            e.syncHash,
          ),
      ],
    );
  }

  @override
  Future<DocumentSyncResponse> download(Set<int> ids) async {
    downloads.add({...ids});
    await beforeDownload?.call();
    return DocumentSyncResponse(
      documents: [
        for (final id in ids)
          if (id != omit) entries[id]!,
      ],
      deletedIds: [],
    );
  }
}

class _NoDocuments implements DocumentContentRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected per-document request');
}

class _NoBooks implements BookRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected catalog request');
}
