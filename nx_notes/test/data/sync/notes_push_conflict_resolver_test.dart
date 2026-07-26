import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/application/ports/clock.dart';
import 'package:nx_notes/data/local/memory/memory_local_notes_store.dart';
import 'package:nx_notes/data/remote/fake/fake_remote_document_gateway.dart';
import 'package:nx_notes/data/sync/notes_push_conflict_resolver.dart';
import 'package:nx_notes/data/sync/notes_sync_store_adapter.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/sync/document_revision.dart';
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
  const key = DocumentKey(localId: 'remote-1', remoteId: 1);
  final now = DateTime.utc(2026, 7, 26);

  offline.PendingMutation mutation() {
    return offline.PendingMutation(
      operationId: 'op-1',
      account: account,
      collection: notesDocumentCollection,
      entityKey: const offline.EntityKey(localId: 'remote-1', remoteId: 1),
      type: offline.MutationType.update,
      payload: const {'body': 'local edit'},
      baseRevision: const offline.Revision('rev-1'),
      createdAt: now,
    );
  }

  test('fetches and durably preserves both conflict versions', () async {
    final local = MemoryLocalNotesStore(accountKey: 'prod:user-1');
    addTearDown(local.dispose);
    await local.importRemoteDocuments([
      RemoteDocument(
        key: key,
        document: offlineTestDocument(id: 1, body: 'base'),
        revision: const RemoteRevision('rev-1'),
      ),
    ]);
    await local.saveDraftAndEnqueue(
      offlineLocalDocument(
        localId: 'remote-1',
        remoteId: 1,
        accountKey: 'prod:user-1',
        body: 'local edit',
      ),
      operation: offlinePendingOperation(
        operationId: 'op-1',
        localId: 'remote-1',
        remoteId: 1,
        accountKey: 'prod:user-1',
        body: 'local edit',
      ),
    );

    final remote = FakeRemoteDocumentGateway();
    remote.seed(
      RemoteDocument(
        key: key,
        document: offlineTestDocument(id: 1, body: 'remote edit'),
        revision: const RemoteRevision('rev-2'),
      ),
    );
    final resolver = NotesPushConflictResolver(
      localStore: local,
      remoteGateway: remote,
      clock: _Clock(now),
      account: account,
    );

    await resolver.resolvePushConflict(
      mutation: mutation(),
      failure: const offline.SyncFailure(
        kind: offline.SyncFailureKind.conflict,
        message: 'stale revision',
      ),
    );

    final conflict = (await local.conflicts()).single;
    expect(conflict.localDocument.document, 'local edit');
    expect(conflict.remoteDocument.document, 'remote edit');
    expect(conflict.remoteRevision, const RemoteRevision('rev-2'));
    expect(
      (await local.getDocument(key))?.syncState,
      DocumentSyncState.conflict,
    );
  });

  test(
    'shared coordinator resolves a Notes push conflict end to end',
    () async {
      final local = MemoryLocalNotesStore(accountKey: 'prod:user-1');
      addTearDown(local.dispose);
      await local.importRemoteDocuments([
        RemoteDocument(
          key: key,
          document: offlineTestDocument(id: 1, body: 'base'),
          revision: const RemoteRevision('rev-1'),
        ),
      ]);
      await local.saveDraftAndEnqueue(
        offlineLocalDocument(
          localId: 'remote-1',
          remoteId: 1,
          accountKey: 'prod:user-1',
          body: 'local edit',
        ),
        operation: offlinePendingOperation(
          operationId: 'op-1',
          localId: 'remote-1',
          remoteId: 1,
          accountKey: 'prod:user-1',
          body: 'local edit',
        ),
      );

      final remote = FakeRemoteDocumentGateway();
      remote.seed(
        RemoteDocument(
          key: key,
          document: offlineTestDocument(id: 1, body: 'remote edit'),
          revision: const RemoteRevision('rev-2'),
        ),
      );
      final storeAdapter = NotesSyncStoreAdapter(
        delegate: local,
        account: account,
      );
      final resolver = NotesPushConflictResolver(
        localStore: local,
        remoteGateway: remote,
        clock: _Clock(now),
        account: account,
      );
      final coordinator = offline.SyncCoordinator(
        store: storeAdapter,
        transport: const _ConflictTransport(),
        collections: const [_DocumentsCollection()],
        pushConflictResolvers: [resolver],
        clock: _Clock(now),
        idGenerator: _Ids(),
      );
      addTearDown(coordinator.dispose);

      final result = await coordinator.synchronize();

      expect(result.failureCount, 1);
      final conflict = (await local.conflicts()).single;
      expect(conflict.localDocument.document, 'local edit');
      expect(conflict.remoteDocument.document, 'remote edit');
      expect(
        (await local.getDocument(key))?.syncState,
        DocumentSyncState.conflict,
      );
      expect(await storeAdapter.pendingMutations(), hasLength(1));
    },
  );

  test(
    'does nothing when the remote conflict record cannot be found',
    () async {
      final local = MemoryLocalNotesStore(accountKey: 'prod:user-1');
      addTearDown(local.dispose);
      await local.importRemoteDocuments([
        RemoteDocument(
          key: key,
          document: offlineTestDocument(id: 1),
          revision: const RemoteRevision('rev-1'),
        ),
      ]);
      final resolver = NotesPushConflictResolver(
        localStore: local,
        remoteGateway: FakeRemoteDocumentGateway(),
        clock: _Clock(now),
        account: account,
      );

      await resolver.resolvePushConflict(
        mutation: mutation(),
        failure: const offline.SyncFailure(
          kind: offline.SyncFailureKind.conflict,
          message: 'stale revision',
        ),
      );

      expect(await local.conflicts(), isEmpty);
    },
  );

  test('rejects non-conflict failures and cross-account mutations', () async {
    final local = MemoryLocalNotesStore(accountKey: 'prod:user-1');
    addTearDown(local.dispose);
    final resolver = NotesPushConflictResolver(
      localStore: local,
      remoteGateway: FakeRemoteDocumentGateway(),
      clock: _Clock(now),
      account: account,
    );

    await expectLater(
      resolver.resolvePushConflict(
        mutation: mutation(),
        failure: const offline.SyncFailure(
          kind: offline.SyncFailureKind.transient,
          message: 'offline',
        ),
      ),
      throwsStateError,
    );
    final otherMutation = offline.PendingMutation(
      operationId: 'op-2',
      account: const offline.AccountScope(
        backend: 'prod',
        userId: 'other',
        application: 'nx_notes',
      ),
      collection: notesDocumentCollection,
      entityKey: const offline.EntityKey(localId: 'remote-1', remoteId: 1),
      type: offline.MutationType.update,
      payload: const {},
      createdAt: now,
    );
    await expectLater(
      resolver.resolvePushConflict(
        mutation: otherMutation,
        failure: const offline.SyncFailure(
          kind: offline.SyncFailureKind.conflict,
          message: 'stale',
        ),
      ),
      throwsStateError,
    );
  });
}

final class _Clock implements Clock, offline.Clock {
  const _Clock(this.value);

  final DateTime value;

  @override
  DateTime now() => value;
}

final class _Ids implements offline.IdGenerator {
  int _value = 0;

  @override
  String nextId() => '${_value++}';
}

final class _ConflictTransport implements offline.SyncTransport {
  const _ConflictTransport();

  @override
  Future<offline.MutationReceipt> push(offline.PendingMutation mutation) {
    throw const offline.SyncTransportException(
      offline.SyncFailure(
        kind: offline.SyncFailureKind.conflict,
        message: 'stale revision',
      ),
    );
  }

  @override
  Future<offline.RemoteChangePage> pull({
    required offline.AccountScope account,
    required String collection,
    required Set<String> modelTypes,
    required offline.SyncCursor? cursor,
  }) async {
    return const offline.RemoteChangePage(
      records: [],
      tombstones: [],
      nextCursor: offline.SyncCursor('cursor-after-conflict'),
    );
  }
}

final class _DocumentsCollection implements offline.SyncCollectionAdapter {
  const _DocumentsCollection();

  @override
  String get collectionName => notesDocumentCollection;

  @override
  Set<String> get modelTypes => const {'Document'};

  @override
  Future<void> applyRemote(offline.RemoteRecord record) async {}

  @override
  Future<void> applyTombstone(offline.RemoteTombstone tombstone) async {}

  @override
  Future<void> preserveConflict(offline.RemoteRecord remote) async {}
}
