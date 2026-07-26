import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/application/ports/clock.dart';
import 'package:nx_notes/application/ports/id_generator.dart';
import 'package:nx_notes/application/ports/remote_document_gateway.dart';
import 'package:nx_notes/application/sync/notes_sync_engine.dart';
import 'package:nx_notes/data/local/memory/memory_local_notes_store.dart';
import 'package:nx_notes/data/remote/fake/fake_remote_document_gateway.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/sync/document_revision.dart';
import 'package:nx_notes/domain/sync/pending_operation.dart';
import 'package:nx_notes/domain/sync/remote_document.dart';
import 'package:nx_notes/domain/sync/sync_failure.dart';
import 'package:nx_notes/domain/sync/sync_state.dart';
import 'package:nx_notes/domain/sync/sync_status.dart';

import '../../support/offline_fixtures.dart';
import '../../support/offline_sync_engine.dart';

void main() {
  const accountKey = 'prod:user-1';
  final now = DateTime.utc(2026, 1, 2);

  late MemoryLocalNotesStore local;
  late FakeRemoteDocumentGateway remote;
  late MutableClock clock;
  late NotesSyncEngine engine;

  setUp(() {
    local = MemoryLocalNotesStore(accountKey: accountKey);
    remote = FakeRemoteDocumentGateway();
    clock = MutableClock(now);
    engine = createOfflineTestSyncEngine(
      localStore: local,
      remoteGateway: remote,
      clock: clock,
      idGenerator: SequenceIdGenerator(),
    );
  });

  tearDown(() async {
    await engine.dispose();
    await local.dispose();
  });

  test('pushes an offline create and assigns its remote identity', () async {
    final document = offlineLocalDocument(
      remoteId: null,
      serverRevision: null,
      baseServerRevision: null,
    );
    await local.saveDraftAndEnqueue(
      document,
      operation: offlinePendingOperation(
        remoteId: null,
        type: PendingOperationType.create,
        baseRevision: null,
      ),
    );

    final result = await engine.synchronize();

    expect(result.pushedCount, 1);
    expect(remote.createCalls, 1);
    final saved = await local.getDocument(document.key);
    expect(saved!.key.remoteId, 1000);
    expect(saved.syncState, DocumentSyncState.synced);
    expect(await local.pendingOperations(), isEmpty);
  });

  test('pushes an edit using its base revision', () async {
    final remoteDocument = RemoteDocument(
      key: const DocumentKey(localId: 'local-1', remoteId: 1),
      document: offlineTestDocument(body: 'server body'),
      revision: const RemoteRevision('rev-1'),
    );
    remote.seed(remoteDocument);
    final localDocument = offlineLocalDocument(body: 'offline edit');
    await local.saveDraftAndEnqueue(
      localDocument,
      operation: offlinePendingOperation(body: 'offline edit'),
    );

    final result = await engine.synchronize();

    expect(result.pushedCount, 1);
    expect(remote.documents.single.document.document, 'offline edit');
    expect(
      (await local.getDocument(localDocument.key))!.syncState,
      DocumentSyncState.synced,
    );
  });

  test('pushes a recoverable local deletion conditionally', () async {
    final document = offlineLocalDocument();
    remote.seed(
      RemoteDocument(
        key: document.key,
        document: document.document,
        revision: const RemoteRevision('rev-1'),
      ),
    );
    await local.saveDraftAndEnqueue(
      document.copyWith(deletedLocally: true),
      operation: offlinePendingOperation(type: PendingOperationType.delete),
    );

    final result = await engine.synchronize();

    expect(result.pushedCount, 1);
    expect(remote.deleteCalls, 1);
    expect(remote.documents.single.deleted, isTrue);
    expect(await local.pendingOperations(), isEmpty);
  });

  test('pulls a new remote document and advances the cursor', () async {
    remote.seed(
      RemoteDocument(
        key: const DocumentKey(localId: 'remote-local', remoteId: 42),
        document: offlineTestDocument(id: 42, body: 'from server'),
        revision: const RemoteRevision('rev-1'),
      ),
    );

    final result = await engine.synchronize();

    expect(result.pulledCount, 1);
    expect(
      (await local.getDocument(
        const DocumentKey(localId: 'remote-local'),
      ))!.document.document,
      'from server',
    );
    expect(await local.readSyncCursor(), '1');
  });

  test('repeated synchronization is idempotent', () async {
    final document = offlineLocalDocument(
      remoteId: null,
      serverRevision: null,
      baseServerRevision: null,
    );
    await local.saveDraftAndEnqueue(
      document,
      operation: offlinePendingOperation(
        remoteId: null,
        type: PendingOperationType.create,
        baseRevision: null,
      ),
    );

    await engine.synchronize();
    final second = await engine.synchronize();

    expect(remote.documents, hasLength(1));
    expect(second.pushedCount, 0);
    expect(second.pulledCount, 0);
  });

  test(
    'transient failure schedules retry and does not lose the edit',
    () async {
      remote.seed(
        RemoteDocument(
          key: const DocumentKey(localId: 'local-1', remoteId: 1),
          document: offlineTestDocument(),
          revision: const RemoteRevision('rev-1'),
        ),
      );
      await local.saveDraftAndEnqueue(
        offlineLocalDocument(body: 'keep me'),
        operation: offlinePendingOperation(body: 'keep me'),
      );
      remote.failNext(
        const RemoteGatewayException(
          SyncFailure(kind: SyncFailureKind.transient, message: 'timeout'),
        ),
      );

      final failed = await engine.synchronize();
      final operation = (await local.pendingOperations()).single;

      expect(failed.failureCount, 1);
      expect(operation.status, PendingOperationStatus.retryWaiting);
      expect(operation.attemptCount, 1);
      expect(operation.nextAttemptAt, now.add(const Duration(seconds: 2)));

      clock.value = operation.nextAttemptAt!;
      final retried = await engine.synchronize();
      expect(retried.pushedCount, 1);
      expect(remote.documents.single.document.document, 'keep me');
    },
  );

  test(
    'retry after a lost response does not duplicate a server create',
    () async {
      final document = offlineLocalDocument(
        remoteId: null,
        serverRevision: null,
        baseServerRevision: null,
      );
      await local.saveDraftAndEnqueue(
        document,
        operation: offlinePendingOperation(
          remoteId: null,
          type: PendingOperationType.create,
          baseRevision: null,
        ),
      );
      remote.failAfterNextCommit(
        const RemoteGatewayException(
          SyncFailure(
            kind: SyncFailureKind.transient,
            message: 'response was lost',
          ),
        ),
      );

      await engine.synchronize();
      final pending = (await local.pendingOperations()).single;
      expect(remote.documents, hasLength(1));

      clock.value = pending.nextAttemptAt!;
      await engine.dispose();
      engine = createOfflineTestSyncEngine(
        localStore: local,
        remoteGateway: remote,
        clock: clock,
        idGenerator: SequenceIdGenerator(),
      );
      final recovered = await engine.synchronize();

      expect(recovered.pushedCount, 1);
      expect(remote.documents, hasLength(1));
      expect(remote.createCalls, 2);
      expect(await local.pendingOperations(), isEmpty);
    },
  );

  test('one failed document does not block an unrelated operation', () async {
    for (var id = 1; id <= 2; id++) {
      remote.seed(
        RemoteDocument(
          key: DocumentKey(localId: 'local-$id', remoteId: id),
          document: offlineTestDocument(id: id),
          revision: RemoteRevision('rev-$id'),
        ),
      );
      await local.saveDraftAndEnqueue(
        offlineLocalDocument(
          localId: 'local-$id',
          remoteId: id,
          body: 'edit $id',
          serverRevision: RemoteRevision('rev-$id'),
          baseServerRevision: RemoteRevision('rev-$id'),
        ),
        operation: offlinePendingOperation(
          operationId: 'operation-$id',
          localId: 'local-$id',
          remoteId: id,
          body: 'edit $id',
          baseRevision: RemoteRevision('rev-$id'),
          createdAt: now.add(Duration(seconds: id)),
        ),
      );
    }
    remote.failNext(
      const RemoteGatewayException(
        SyncFailure(kind: SyncFailureKind.transient, message: 'temporary'),
      ),
    );

    final result = await engine.synchronize();

    expect(result.pushedCount, 1);
    expect(
      (await local.pendingOperations()).single.documentKey.localId,
      'local-1',
    );
    expect(
      remote.documents
          .singleWhere((item) => item.key.localId == 'local-2')
          .document
          .document,
      'edit 2',
    );
  });

  test('records both versions when a conditional update conflicts', () async {
    remote.seed(
      RemoteDocument(
        key: const DocumentKey(localId: 'local-1', remoteId: 1),
        document: offlineTestDocument(body: 'server edit'),
        revision: const RemoteRevision('rev-2'),
      ),
    );
    await local.saveDraftAndEnqueue(
      offlineLocalDocument(body: 'local edit'),
      operation: offlinePendingOperation(body: 'local edit'),
    );

    final result = await engine.synchronize();
    final conflict = (await local.conflicts()).single;

    expect(result.conflictCount, greaterThanOrEqualTo(1));
    expect(conflict.localDocument.document, 'local edit');
    expect(conflict.remoteDocument.document, 'server edit');
    expect(
      (await local.getDocument(conflict.documentKey))!.syncState,
      DocumentSyncState.conflict,
    );
  });

  test('authentication failure blocks the run without pulling', () async {
    await local.saveDraftAndEnqueue(
      offlineLocalDocument(),
      operation: offlinePendingOperation(),
    );
    remote.failNext(
      const RemoteGatewayException(
        SyncFailure(
          kind: SyncFailureKind.authentication,
          message: 'signed out',
        ),
      ),
    );

    final result = await engine.synchronize();

    expect(result.failureCount, 1);
    expect(engine.status.activity, SyncActivity.blocked);
    expect(await local.readSyncCursor(), isNull);
  });

  test('concurrent triggers share one synchronization run', () async {
    final delayed = DelayedRemoteGateway(remote);
    await engine.dispose();
    engine = createOfflineTestSyncEngine(
      localStore: local,
      remoteGateway: delayed,
      clock: clock,
      idGenerator: SequenceIdGenerator(),
    );

    final first = engine.synchronize(reason: SyncReason.appStarted);
    final second = engine.synchronize(reason: SyncReason.connectivityRestored);
    expect(identical(first, second), isTrue);

    delayed.release();
    await Future.wait(<Future<SyncRunResult>>[first, second]);
    expect(delayed.pullCalls, 1);
  });
}

class MutableClock implements Clock {
  MutableClock(this.value);

  DateTime value;

  @override
  DateTime now() => value;
}

class SequenceIdGenerator implements IdGenerator {
  var _next = 0;

  @override
  String nextId() => '${++_next}';
}

class DelayedRemoteGateway implements RemoteDocumentGateway {
  DelayedRemoteGateway(this.delegate);

  final RemoteDocumentGateway delegate;
  final Completer<void> _gate = Completer<void>();
  var pullCalls = 0;

  void release() => _gate.complete();

  @override
  Future<RemoteWriteResult> deleteDocument(
    RemoteDeleteRequest request, {
    required String idempotencyKey,
    required RemoteRevision expectedRevision,
  }) => delegate.deleteDocument(
    request,
    idempotencyKey: idempotencyKey,
    expectedRevision: expectedRevision,
  );

  @override
  Future<RemoteWriteResult> createDocument(
    RemoteCreateRequest request, {
    required String idempotencyKey,
  }) => delegate.createDocument(request, idempotencyKey: idempotencyKey);

  @override
  Future<RemoteChangeSet> pullChanges({required String? cursor}) async {
    pullCalls++;
    await _gate.future;
    return delegate.pullChanges(cursor: cursor);
  }

  @override
  Future<RemoteWriteResult> updateDocument(
    RemoteUpdateRequest request, {
    required String idempotencyKey,
    required RemoteRevision expectedRevision,
  }) => delegate.updateDocument(
    request,
    idempotencyKey: idempotencyKey,
    expectedRevision: expectedRevision,
  );
}
