import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/application/ports/local_notes_store.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/document/document_query.dart';
import 'package:nx_notes/domain/sync/document_revision.dart';
import 'package:nx_notes/domain/sync/pending_operation.dart';
import 'package:nx_notes/domain/sync/remote_document.dart';
import 'package:nx_notes/domain/sync/sync_failure.dart';
import 'package:nx_notes/domain/sync/sync_conflict.dart';
import 'package:nx_notes/domain/sync/sync_state.dart';

import '../offline_fixtures.dart';

typedef LocalStoreFactory = Future<LocalNotesStore> Function();
typedef LocalStoreDisposer = Future<void> Function(LocalNotesStore store);

void runLocalNotesStoreContract({
  required LocalStoreFactory createStore,
  required LocalStoreDisposer disposeStore,
}) {
  late LocalNotesStore store;

  setUp(() async {
    store = await createStore();
  });

  tearDown(() async {
    await disposeStore(store);
  });

  test('saves a document and outbox entry together', () async {
    final document = offlineLocalDocument();
    final operation = offlinePendingOperation();

    await store.saveDraftAndEnqueue(document, operation: operation);

    final saved = await store.getDocument(document.key);
    expect(saved, isNotNull);
    expect(saved!.document.document, 'Test body');
    expect(saved.syncState, DocumentSyncState.queued);
    expect(await store.pendingOperations(), hasLength(1));
  });

  test('rejects an account mismatch without a partial write', () async {
    final document = offlineLocalDocument(accountKey: 'another:user');
    final operation = offlinePendingOperation(accountKey: 'another:user');

    await expectLater(
      store.saveDraftAndEnqueue(document, operation: operation),
      throwsStateError,
    );

    expect(await store.getDocument(document.key), isNull);
    expect(await store.pendingOperations(), isEmpty);
  });

  test('coalesces repeated saves for one document', () async {
    await store.saveDraftAndEnqueue(
      offlineLocalDocument(body: 'one'),
      operation: offlinePendingOperation(body: 'one'),
    );
    await store.saveDraftAndEnqueue(
      offlineLocalDocument(body: 'two'),
      operation: offlinePendingOperation(
        operationId: 'operation-2',
        body: 'two',
      ),
    );

    final operations = await store.pendingOperations();
    expect(operations, hasLength(1));
    expect(operations.single.operationId, 'operation-1');
    expect(operations.single.payload['body'], 'two');
    expect(
      (await store.getDocument(
        const DocumentKey(localId: 'local-1'),
      ))!.document.document,
      'two',
    );
  });

  test('claims one operation and respects its lease', () async {
    final now = DateTime.utc(2026, 1, 1, 12);
    await store.saveDraftAndEnqueue(
      offlineLocalDocument(),
      operation: offlinePendingOperation(),
    );

    final first = await store.claimNextOperation(
      workerId: 'worker-1',
      lease: const Duration(minutes: 1),
      now: now,
    );
    final blocked = await store.claimNextOperation(
      workerId: 'worker-2',
      lease: const Duration(minutes: 1),
      now: now,
    );
    final reclaimed = await store.claimNextOperation(
      workerId: 'worker-2',
      lease: const Duration(minutes: 1),
      now: now.add(const Duration(minutes: 1)),
    );

    expect(first!.leaseOwner, 'worker-1');
    expect(blocked, isNull);
    expect(reclaimed!.operationId, first.operationId);
    expect(reclaimed.leaseOwner, 'worker-2');
  });

  test('concurrent workers cannot claim the same operation', () async {
    final now = DateTime.utc(2026, 1, 1, 12);
    await store.saveDraftAndEnqueue(
      offlineLocalDocument(),
      operation: offlinePendingOperation(),
    );

    final claims = await Future.wait([
      store.claimNextOperation(
        workerId: 'tab-1',
        lease: const Duration(minutes: 1),
        now: now,
      ),
      store.claimNextOperation(
        workerId: 'tab-2',
        lease: const Duration(minutes: 1),
        now: now,
      ),
    ]);

    expect(claims.whereType<PendingOperation>(), hasLength(1));
  });

  test('failure persists retry metadata and releases lease', () async {
    final now = DateTime.utc(2026, 1, 1, 12);
    await store.saveDraftAndEnqueue(
      offlineLocalDocument(),
      operation: offlinePendingOperation(),
    );
    final claimed = await store.claimNextOperation(
      workerId: 'worker',
      lease: const Duration(minutes: 1),
      now: now,
    );

    await store.failOperation(
      claimed!.operationId,
      failure: const SyncFailure(
        kind: SyncFailureKind.transient,
        message: 'backend unavailable',
      ),
      retryAt: now.add(const Duration(minutes: 2)),
    );

    final failed = (await store.pendingOperations()).single;
    expect(failed.status, PendingOperationStatus.retryWaiting);
    expect(failed.attemptCount, 1);
    expect(failed.leaseOwner, isNull);
    expect(failed.lastError, 'backend unavailable');
    final local = await store.getDocument(claimed.documentKey);
    expect(local!.syncState, DocumentSyncState.retryWaiting);
  });

  test('completion assigns server identity and revision atomically', () async {
    final now = DateTime.utc(2026, 1, 1, 12);
    final document = offlineLocalDocument(
      remoteId: null,
      serverRevision: null,
      baseServerRevision: null,
    );
    await store.saveDraftAndEnqueue(
      document,
      operation: offlinePendingOperation(
        remoteId: null,
        type: PendingOperationType.create,
        baseRevision: null,
      ),
    );
    final claimed = await store.claimNextOperation(
      workerId: 'worker',
      lease: const Duration(minutes: 1),
      now: now,
    );

    await store.completeOperation(
      claimed!.operationId,
      result: const RemoteWriteResult(
        key: DocumentKey(localId: 'local-1', remoteId: 99),
        revision: RemoteRevision('rev-99'),
      ),
    );

    expect(await store.pendingOperations(), isEmpty);
    final saved = await store.getDocument(claimed.documentKey);
    expect(saved!.key.remoteId, 99);
    expect(saved.serverRevision, const RemoteRevision('rev-99'));
    expect(saved.baseServerRevision, const RemoteRevision('rev-99'));
    expect(saved.syncState, DocumentSyncState.synced);
  });

  test('remote import does not overwrite a locally dirty document', () async {
    await store.saveDraftAndEnqueue(
      offlineLocalDocument(body: 'local'),
      operation: offlinePendingOperation(body: 'local'),
    );
    await store.importRemoteDocuments(<RemoteDocument>[
      RemoteDocument(
        key: const DocumentKey(localId: 'local-1', remoteId: 1),
        document: offlineTestDocument(body: 'remote'),
        revision: const RemoteRevision('rev-2'),
      ),
    ]);

    final saved = await store.getDocument(
      const DocumentKey(localId: 'local-1'),
    );
    expect(saved!.document.document, 'local');
  });

  test('document streams publish initial and changed values', () async {
    final emissions = <String?>[];
    final subscription = store
        .watchDocument(const DocumentKey(localId: 'local-1'))
        .map((value) => value?.document.document)
        .listen(emissions.add);
    await Future<void>.delayed(Duration.zero);

    await store.saveDraftAndEnqueue(
      offlineLocalDocument(body: 'written'),
      operation: offlinePendingOperation(body: 'written'),
    );
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(emissions, <String?>[null, 'written']);
  });

  test('query stream filters search and pinned documents', () async {
    await store.importRemoteDocuments(<RemoteDocument>[
      RemoteDocument(
        key: const DocumentKey(localId: 'one', remoteId: 1),
        document: offlineTestDocument(
          id: 1,
          title: 'Alpha roadmap',
          pinned: true,
        ),
        revision: const RemoteRevision('one'),
      ),
      RemoteDocument(
        key: const DocumentKey(localId: 'two', remoteId: 2),
        document: offlineTestDocument(id: 2, title: 'Beta notes'),
        revision: const RemoteRevision('two'),
      ),
    ]);

    final rows = await store
        .watchDocuments(
          const DocumentQuery(searchText: 'alpha', pinnedOnly: true),
        )
        .first;
    expect(rows.map((row) => row.key.localId), <String>['one']);
  });

  test('persists the synchronization cursor', () async {
    expect(await store.readSyncCursor(), isNull);
    await store.writeSyncCursor('cursor-42');
    expect(await store.readSyncCursor(), 'cursor-42');
  });

  test('records both sides of a conflict and marks the local record', () async {
    final local = offlineLocalDocument(body: 'local');
    await store.saveDraftAndEnqueue(
      local,
      operation: offlinePendingOperation(body: 'local'),
    );
    await store.recordConflict(
      SyncConflict(
        documentKey: local.key,
        localDocument: local.document,
        remoteDocument: offlineTestDocument(body: 'remote'),
        remoteRevision: const RemoteRevision('remote-revision'),
        detectedAt: DateTime.utc(2026, 1, 2),
      ),
    );

    final conflicts = await store.conflicts();
    expect(conflicts, hasLength(1));
    expect(conflicts.single.localDocument.document, 'local');
    expect(conflicts.single.remoteDocument.document, 'remote');
    expect(
      (await store.getDocument(local.key))!.syncState,
      DocumentSyncState.conflict,
    );
  });
}
