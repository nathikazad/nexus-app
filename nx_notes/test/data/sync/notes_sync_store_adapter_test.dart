import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/data/local/drift/drift_local_notes_store.dart';
import 'package:nx_notes/data/local/drift/notes_database.dart';
import 'package:nx_notes/data/local/memory/memory_local_notes_store.dart';
import 'package:nx_notes/data/sync/notes_sync_store_adapter.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/sync/document_revision.dart';
import 'package:nx_notes/domain/sync/pending_operation.dart';
import 'package:nx_notes/domain/sync/remote_document.dart';
import 'package:nx_notes/domain/sync/sync_state.dart';
import 'package:nx_offline/nx_offline.dart' as offline;

import '../../support/offline_fixtures.dart';

void main() {
  const account = offline.AccountScope(
    backend: 'prod',
    userId: 'user-1',
    application: 'nx_notes',
  );
  const documentKey = DocumentKey(localId: 'remote-1', remoteId: 1);
  const offlineKey = offline.EntityKey(localId: 'remote-1', remoteId: 1);
  final now = DateTime.utc(2026, 7, 26);

  Future<void> seedDocument(MemoryLocalNotesStore store) {
    return store.importRemoteDocuments([
      RemoteDocument(
        key: documentKey,
        document: offlineTestDocument(id: 1),
        revision: const RemoteRevision('r1'),
      ),
    ]);
  }

  offline.PendingMutation mutation({
    String operationId = 'op-1',
    offline.MutationType type = offline.MutationType.update,
    offline.AccountScope mutationAccount = account,
    String collection = notesDocumentCollection,
    String body = 'offline edit',
    String? operationGroup,
  }) {
    return offline.PendingMutation(
      operationId: operationId,
      account: mutationAccount,
      collection: collection,
      entityKey: offlineKey,
      type: type,
      payload: {'body': body},
      baseRevision: const offline.Revision('r1'),
      createdAt: now,
      operationGroup: operationGroup,
    );
  }

  test('adapter preserves the existing Notes account key and outbox', () async {
    final store = MemoryLocalNotesStore(accountKey: 'prod:user-1');
    addTearDown(store.dispose);
    await seedDocument(store);
    final adapter = NotesSyncStoreAdapter(delegate: store, account: account);

    await adapter.enqueue(mutation());

    final notesPending = (await store.pendingOperations()).single;
    expect(notesPending.operationId, 'op-1');
    expect(notesPending.accountKey, 'prod:user-1');
    expect(notesPending.documentKey, documentKey);
    expect(notesPending.payload, {'body': 'offline edit'});

    final sharedPending = (await adapter.pendingMutations()).single;
    expect(sharedPending.account, account);
    expect(sharedPending.collection, notesDocumentCollection);
    expect(sharedPending.entityKey, offlineKey);
    expect(sharedPending.baseRevision, const offline.Revision('r1'));
  });

  test(
    'claim, failure, and completion delegate without schema changes',
    () async {
      final store = MemoryLocalNotesStore(accountKey: 'prod:user-1');
      addTearDown(store.dispose);
      await seedDocument(store);
      final adapter = NotesSyncStoreAdapter(delegate: store, account: account);
      await adapter.enqueue(mutation());

      final claimed = await adapter.claimNext(
        workerId: 'shared-worker',
        now: now,
        lease: const Duration(minutes: 1),
      );
      expect(claimed?.leaseOwner, 'shared-worker');

      await adapter.fail(
        'op-1',
        failure: const offline.SyncFailure(
          kind: offline.SyncFailureKind.transient,
          message: 'offline',
        ),
        retryAt: now.add(const Duration(seconds: 2)),
      );
      expect(
        (await store.pendingOperations()).single.status,
        PendingOperationStatus.retryWaiting,
      );
      expect(
        (await store.getDocument(documentKey))?.syncState,
        DocumentSyncState.retryWaiting,
      );

      await adapter.claimNext(
        workerId: 'shared-worker-2',
        now: now.add(const Duration(seconds: 2)),
        lease: const Duration(minutes: 1),
      );
      await adapter.complete(
        const offline.MutationReceipt(
          operationId: 'op-1',
          entityKey: offlineKey,
          revision: offline.Revision('r2'),
        ),
      );

      expect(await store.pendingOperations(), isEmpty);
      final saved = await store.getDocument(documentKey);
      expect(saved?.serverRevision, const RemoteRevision('r2'));
      expect(saved?.syncState, DocumentSyncState.synced);
    },
  );

  test('cursor and full conflict documents map in both directions', () async {
    final store = MemoryLocalNotesStore(accountKey: 'prod:user-1');
    addTearDown(store.dispose);
    await seedDocument(store);
    final codec = const NotesSyncDocumentCodec();
    final adapter = NotesSyncStoreAdapter(
      delegate: store,
      account: account,
      documentCodec: codec,
    );

    await adapter.writeCursor(
      notesDocumentCollection,
      const offline.SyncCursor('cursor-1'),
    );
    expect(
      await adapter.readCursor(notesDocumentCollection),
      const offline.SyncCursor('cursor-1'),
    );

    final local = offlineTestDocument(id: 1, body: 'local body');
    final remote = offlineTestDocument(id: 1, body: 'remote body');
    await adapter.recordConflict(
      offline.SyncConflict(
        account: account,
        collection: notesDocumentCollection,
        entityKey: offlineKey,
        localPayload: codec.encode(local),
        remotePayload: codec.encode(remote),
        remoteRevision: const offline.Revision('r2'),
        detectedAt: now,
      ),
    );

    final conflict = (await store.conflicts()).single;
    expect(conflict.localDocument.document, 'local body');
    expect(conflict.remoteDocument.document, 'remote body');
    expect(conflict.remoteRevision, const RemoteRevision('r2'));
    expect(
      (await store.getDocument(documentKey))?.syncState,
      DocumentSyncState.conflict,
    );
  });

  test(
    'rejects lossy collection, account, relation, and group mappings',
    () async {
      final store = MemoryLocalNotesStore(accountKey: 'prod:user-1');
      addTearDown(store.dispose);
      await seedDocument(store);
      final adapter = NotesSyncStoreAdapter(delegate: store, account: account);

      await expectLater(
        adapter.enqueue(mutation(collection: 'tasks')),
        throwsStateError,
      );
      await expectLater(
        adapter.enqueue(
          mutation(
            mutationAccount: const offline.AccountScope(
              backend: 'prod',
              userId: 'user-2',
              application: 'nx_notes',
            ),
          ),
        ),
        throwsStateError,
      );
      await expectLater(
        adapter.enqueue(mutation(type: offline.MutationType.relation)),
        throwsStateError,
      );
      await expectLater(
        adapter.enqueue(mutation(operationGroup: 'group-1')),
        throwsStateError,
      );
      expect(await store.pendingOperations(), isEmpty);
    },
  );

  test('existing Notes database rows remain readable after restart', () async {
    final directory = await Directory.systemTemp.createTemp(
      'notes_sync_adapter_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/notes.sqlite');

    var database = NotesDatabase(NativeDatabase(file));
    var store = DriftLocalNotesStore(
      database: database,
      accountKey: 'prod:user-1',
    );
    var adapter = NotesSyncStoreAdapter(delegate: store, account: account);
    await store.importRemoteDocuments([
      RemoteDocument(
        key: documentKey,
        document: offlineTestDocument(id: 1, body: 'persisted body'),
        revision: const RemoteRevision('r1'),
      ),
    ]);
    await adapter.enqueue(mutation(body: 'persisted edit'));
    await adapter.writeCursor(
      notesDocumentCollection,
      const offline.SyncCursor('cursor-before-restart'),
    );
    await database.close();

    database = NotesDatabase(NativeDatabase(file));
    addTearDown(database.close);
    store = DriftLocalNotesStore(database: database, accountKey: 'prod:user-1');
    adapter = NotesSyncStoreAdapter(delegate: store, account: account);

    expect((await adapter.pendingMutations()).single.operationId, 'op-1');
    expect(
      await adapter.readCursor(notesDocumentCollection),
      const offline.SyncCursor('cursor-before-restart'),
    );
    expect(
      (await store.getDocument(documentKey))?.document.document,
      'persisted body',
    );
  });

  test('constructor rejects a mismatched existing Notes partition', () async {
    final store = MemoryLocalNotesStore(accountKey: 'prod:other-user');
    addTearDown(store.dispose);

    expect(
      () => NotesSyncStoreAdapter(delegate: store, account: account),
      throwsStateError,
    );
  });
}
