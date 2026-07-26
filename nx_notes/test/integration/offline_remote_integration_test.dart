import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/application/ports/clock.dart';
import 'package:nx_notes/application/ports/id_generator.dart';
import 'package:nx_notes/application/ports/local_notes_store.dart';
import 'package:nx_notes/application/sync/notes_sync_engine.dart';
import 'package:nx_notes/data/document/fake_document_repository.dart';
import 'package:nx_notes/data/local/drift/drift_local_notes_store.dart';
import 'package:nx_notes/data/local/drift/notes_database.dart';
import 'package:nx_notes/data/local/memory/memory_local_notes_store.dart';
import 'package:nx_notes/data/remote/kgql/kgql_remote_document_gateway.dart';
import 'package:nx_notes/data/sync/nx_offline_notes_sync_engine.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/sync/pending_operation.dart';
import 'package:nx_notes/domain/sync/sync_state.dart';
import 'package:nx_offline/nx_offline.dart' as offline;

import '../support/offline_fixtures.dart';

void main() {
  const accountKey = 'prod:user-1';

  test(
    'memory store and KGQL adapter create then update through sync',
    () async {
      final repository = FakeDocumentRepository();
      final remote = KgqlRemoteDocumentGateway(repository: repository);
      final local = MemoryLocalNotesStore(accountKey: accountKey);
      addTearDown(local.dispose);
      final engine = _engine(local, remote);
      addTearDown(engine.dispose);
      final createdLocal = offlineLocalDocument(
        localId: 'created-offline',
        remoteId: null,
        body: 'created offline',
        serverRevision: null,
        baseServerRevision: null,
      );
      await local.saveDraftAndEnqueue(
        createdLocal,
        operation: offlinePendingOperation(
          operationId: 'create-operation',
          localId: 'created-offline',
          remoteId: null,
          type: PendingOperationType.create,
          baseRevision: null,
        ),
      );
      await engine.synchronize();
      final created = await local.getDocument(createdLocal.key);

      final edited = created!.copyWith(
        document: created.document.copyWith(document: 'edited offline'),
        syncState: DocumentSyncState.locallyModified,
      );
      await local.saveDraftAndEnqueue(
        edited,
        operation: offlinePendingOperation(
          operationId: 'update-operation',
          localId: edited.key.localId,
          remoteId: edited.key.remoteId,
          body: 'edited offline',
          baseRevision: edited.baseServerRevision,
        ),
      );
      final result = await engine.synchronize();

      expect(result.pushedCount, 1);
      expect(
        (await repository.getById(edited.key.remoteId!))!.document,
        'edited offline',
      );
      expect(
        (await local.getDocument(edited.key))!.syncState,
        DocumentSyncState.synced,
      );
    },
  );

  test('full headless stack imports and partitions local accounts', () async {
    final database = NotesDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = FakeDocumentRepository();
    final remote = KgqlRemoteDocumentGateway(repository: repository);
    final firstStore = DriftLocalNotesStore(
      database: database,
      accountKey: accountKey,
    );
    final firstEngine = _engine(firstStore, remote);
    addTearDown(firstEngine.dispose);

    final result = await firstEngine.synchronize();
    expect(result.pulledCount, greaterThan(0));
    expect(
      await firstStore.getDocument(
        const DocumentKey(localId: 'remote-1', remoteId: 1),
      ),
      isNotNull,
    );

    final secondStore = DriftLocalNotesStore(
      database: database,
      accountKey: 'staging:user-1',
    );
    expect(
      await secondStore.getDocument(
        const DocumentKey(localId: 'remote-1', remoteId: 1),
      ),
      isNull,
    );
  });
}

NotesSyncEngine _engine(
  LocalNotesStore local,
  KgqlRemoteDocumentGateway remote,
) {
  return NxOfflineNotesSyncEngine(
    localStore: local,
    remoteGateway: remote,
    account: const offline.AccountScope(
      backend: 'prod',
      userId: 'user-1',
      application: 'nx_notes',
    ),
    clock: const SystemTestClock(),
    idGenerator: SequenceIdGenerator(),
  );
}

class SystemTestClock implements Clock {
  const SystemTestClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

class SequenceIdGenerator implements IdGenerator {
  var _next = 0;

  @override
  String nextId() => '${++_next}';
}
