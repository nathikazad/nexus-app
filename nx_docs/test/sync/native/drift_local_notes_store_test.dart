import 'dart:io';

import 'package:drift/native.dart';
import 'package:nx_docs/library/models/catalog_query.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/sync/native/local_notes_store.dart';
import 'package:nx_docs/sync/native/drift_local_notes_store.dart';
import 'package:nx_docs/sync/native/notes_database.dart';
import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/sync/sync_models.dart';

import '../../support/contracts/local_notes_store_contract.dart';
import '../../support/offline_fixtures.dart';

void main() {
  group('DriftLocalNotesStore contract', () {
    runLocalNotesStoreContract(
      createStore: () async => DriftLocalNotesStore(
        database: NotesDatabase(NativeDatabase.memory()),
        accountKey: 'prod:user-1',
      ),
      disposeStore: (LocalNotesStore store) {
        return (store as DriftLocalNotesStore).database.close();
      },
    );
  });

  test('cached books and chapters stay out of all document catalogs', () async {
    final database = NotesDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = DriftLocalNotesStore(
      database: database,
      accountKey: 'prod:user-1',
    );
    final rows =
        [
              offlineTestDocument(
                id: 2,
                title: 'Shared book',
                pinned: true,
                updatedAt: DateTime.utc(2026, 3),
              ).copyWith(modelTypeName: 'Book'),
              offlineTestDocument(
                id: 3,
                title: 'Shared chapter',
                pinned: true,
                updatedAt: DateTime.utc(2026, 2),
              ).copyWith(modelTypeName: 'Book Chapter'),
              offlineTestDocument(
                id: 1,
                title: 'Shared document',
                pinned: true,
              ),
            ]
            .map(
              (d) => DocumentSummary.fromDocument(
                d.copyWith(
                  tagsBySystem: {
                    'Topic': ['Ideas'],
                  },
                ),
              ),
            )
            .toList();
    for (final query in [
      const CatalogQuery.all(),
      const CatalogQuery.recent(limit: 1),
      const CatalogQuery.pinned(limit: 1),
    ]) {
      await store.replaceCatalog(query, rows);
      expect((await store.readCatalog(query)).map((d) => d.id), [1]);
    }
    for (final query in [
      const CatalogQuery.search('Shared'),
      const CatalogQuery.tag(DocumentTagFilter(system: 'Topic', node: 'Ideas')),
    ]) {
      expect((await store.readCatalog(query)).map((d) => d.id), [1]);
    }
    expect(
      await database.select(database.documentSummaries).get(),
      hasLength(3),
    );
  });

  test('documents and pending work survive a database restart', () async {
    final directory = await Directory.systemTemp.createTemp(
      'nx_docs_drift_restart_',
    );
    final file = File('${directory.path}/notes.sqlite');
    addTearDown(() => directory.delete(recursive: true));

    var database = NotesDatabase(NativeDatabase(file));
    var store = DriftLocalNotesStore(
      database: database,
      accountKey: 'prod:user-1',
    );
    await store.saveDraftAndEnqueue(
      offlineLocalDocument(body: 'survives restart'),
      operation: offlinePendingOperation(
        type: PendingOperationType.update,
        body: 'survives restart',
      ),
    );
    await database.close();

    database = NotesDatabase(NativeDatabase(file));
    store = DriftLocalNotesStore(database: database, accountKey: 'prod:user-1');
    addTearDown(database.close);

    final document = await store.getDocument(
      const DocumentKey(localId: 'local-1'),
    );
    final operations = await store.pendingOperations();
    expect(document!.document.document, 'survives restart');
    expect(document.document.jsonDocument['format'], 'appflowy_document');
    expect(operations, hasLength(1));
    expect(operations.single.payload['body'], 'survives restart');
  });

  test('database enforces one pending operation per document', () async {
    final database = NotesDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = DriftLocalNotesStore(
      database: database,
      accountKey: 'prod:user-1',
    );

    await store.saveDraftAndEnqueue(
      offlineLocalDocument(body: 'first'),
      operation: offlinePendingOperation(body: 'first'),
    );
    await store.saveDraftAndEnqueue(
      offlineLocalDocument(body: 'second'),
      operation: offlinePendingOperation(
        operationId: 'second-operation',
        body: 'second',
      ),
    );

    final rows = await database.select(database.syncOutbox).get();
    expect(rows, hasLength(1));
    expect(rows.single.operationId, 'operation-1');
  });
}
