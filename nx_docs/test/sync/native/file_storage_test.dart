import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/library/models/catalog_query.dart';
import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/sync/native/drift_local_notes_store.dart';
import 'package:nx_docs/sync/native/notes_database.dart';
import 'package:nx_docs/sync/sync_models.dart';
import 'package:nx_offline/nx_offline_storage.dart';
import 'package:nx_offline/src/storage/content_files_native.dart';
import '../../support/offline_fixtures.dart';
import '../../support/contracts/local_notes_store_contract.dart';

void main() {
  test(
    'large documents round-trip through workers without entering the summary index',
    () async {
      final dir = await Directory.systemTemp.createTemp('nx-large-document-');
      final db = NotesDatabase(
        NativeDatabase(File('${dir.path}/index.sqlite')),
      );
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      final files = DirectoryContentFiles(Directory('${dir.path}/content'));
      final store = DriftLocalNotesStore(
        database: db,
        accountKey: 'prod:user-1',
        files: files,
      );
      final body = 'large unicode 文本 ' * 10000;
      await store.saveDraftAndEnqueue(
        offlineLocalDocument(body: body),
        operation: offlinePendingOperation(),
      );
      expect(
        (await db.select(db.localDocuments).getSingle()).documentJson.length,
        lessThan(1000),
      );
      expect(
        (await db.select(db.documentSummaries).getSingle()).documentJson.length,
        lessThan(2000),
      );
      expect((await store.getDocumentByRemoteId(1))!.document.document, body);
    },
  );

  test(
    'version 5 upgrade strips duplicate summary bodies and preserves the original document',
    () async {
      final dir = await Directory.systemTemp.createTemp('nx-notes-v5-');
      final path = File('${dir.path}/index.sqlite');
      var db = NotesDatabase(NativeDatabase(path));
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      final legacy = DriftLocalNotesStore(
        database: db,
        accountKey: 'prod:user-1',
      );
      final body = 'old body ' * 1000;
      await legacy.saveDraftAndEnqueue(
        offlineLocalDocument(body: body),
        operation: offlinePendingOperation(),
      );
      // Version 5 has the same tables but can still contain old full-body summaries.
      await db.customStatement(
        'UPDATE document_summaries SET document_json = (SELECT document_json FROM local_documents LIMIT 1)',
      );
      await db.customStatement('PRAGMA user_version = 5');
      await db.close();
      db = NotesDatabase(NativeDatabase(path));
      final files = DirectoryContentFiles(Directory('${dir.path}/content'));
      final store = DriftLocalNotesStore(
        database: db,
        accountKey: 'prod:user-1',
        files: files,
      );
      await store.migrateContent();
      expect(
        (await db.select(db.documentSummaries).getSingle()).documentJson.length,
        lessThan(2000),
      );
      expect((await store.getDocumentByRemoteId(1))!.document.document, body);
      expect(
        (await store.pendingOperations()).single.operationId,
        'operation-1',
      );
    },
  );

  group('filesystem-backed Notes contract', () {
    final directories = <NotesDatabase, Directory>{};
    runLocalNotesStoreContract(
      createStore: () async {
        final dir = await Directory.systemTemp.createTemp('nx-notes-contract-');
        final db = NotesDatabase(
          NativeDatabase(File('${dir.path}/index.sqlite')),
        );
        directories[db] = dir;
        return DriftLocalNotesStore(
          database: db,
          accountKey: 'prod:user-1',
          files: DirectoryContentFiles(Directory('${dir.path}/content')),
        );
      },
      disposeStore: (store) async {
        final db = (store as DriftLocalNotesStore).database;
        await db.close();
        await directories.remove(db)!.delete(recursive: true);
      },
    );
  });

  test(
    'migration preserves pending edits; catalog and manifest never open bodies',
    () async {
      final dir = await Directory.systemTemp.createTemp('nx-notes-files-');
      final db = NotesDatabase(
        NativeDatabase(File('${dir.path}/index.sqlite')),
      );
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      final legacy = DriftLocalNotesStore(
        database: db,
        accountKey: 'prod:user-1',
      );
      await legacy.saveDraftAndEnqueue(
        offlineLocalDocument(body: 'legacy draft'),
        operation: offlinePendingOperation(body: 'legacy draft'),
      );
      final files = DirectoryContentFiles(Directory('${dir.path}/content'));
      final store = DriftLocalNotesStore(
        database: db,
        accountKey: 'prod:user-1',
        files: files,
      );
      await store.migrateContent();
      final row = await db.select(db.localDocuments).getSingle();
      expect(isContentReference(row.documentJson), isTrue);
      expect(
        (await store.pendingOperations()).single.payload['body'],
        'legacy draft',
      );
      final reads = files.reads;
      expect(await store.readCatalog(const CatalogQuery.all()), hasLength(1));
      expect(
        await store.readCatalog(const CatalogQuery.search('test')),
        hasLength(1),
      );
      expect(await store.documentManifest(), hasLength(1));
      expect(files.reads, reads);
      expect(
        (await store.getDocumentByRemoteId(1))!.document.document,
        'legacy draft',
      );
      await store.migrateContent();
      expect(files.writes, 1);
    },
  );

  test(
    'queued upload retains the exact file version after another edit',
    () async {
      final dir = await Directory.systemTemp.createTemp('nx-notes-generation-');
      final db = NotesDatabase(
        NativeDatabase(File('${dir.path}/index.sqlite')),
      );
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      final files = DirectoryContentFiles(Directory('${dir.path}/content'));
      final store = DriftLocalNotesStore(
        database: db,
        accountKey: 'prod:user-1',
        files: files,
      );
      await store.saveDraftAndEnqueue(
        offlineLocalDocument(body: 'A'),
        operation: offlinePendingOperation(body: 'A'),
      );
      final claimed = await store.claimNextOperation(
        workerId: 'worker',
        lease: const Duration(minutes: 1),
        now: DateTime.utc(2026, 1, 2),
      );
      await store.saveDraftAndEnqueue(
        offlineLocalDocument(body: 'B'),
        operation: offlinePendingOperation(operationId: 'new', body: 'B'),
      );
      expect(
        (await store.readQueuedDocument(
          claimed!.payload['body_ref'] as String,
        )).document,
        'A',
      );
      await store.completeOperation(
        claimed.operationId,
        result: const RemoteWriteResult(
          key: DocumentKey(localId: 'local-1', remoteId: 1),
          revision: RemoteRevision('ack'),
        ),
      );
      expect((await store.pendingOperations()).single.operationId, 'new');
      expect((await store.getDocumentByRemoteId(1))!.document.document, 'B');
    },
  );
}
