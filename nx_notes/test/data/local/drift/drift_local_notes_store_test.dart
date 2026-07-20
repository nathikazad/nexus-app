import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/application/ports/local_notes_store.dart';
import 'package:nx_notes/data/local/drift/drift_local_notes_store.dart';
import 'package:nx_notes/data/local/drift/notes_database.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/sync/pending_operation.dart';

import '../../../support/contracts/local_notes_store_contract.dart';
import '../../../support/offline_fixtures.dart';

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

  test('documents and pending work survive a database restart', () async {
    final directory = await Directory.systemTemp.createTemp(
      'nx_notes_drift_restart_',
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
