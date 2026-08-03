import 'package:nx_notes/application/ports/local_notes_store.dart';
import 'package:nx_notes/application/ports/notes_remote_api.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/sync/document_revision.dart';
import 'package:nx_notes/domain/sync/pending_operation.dart';
import 'package:nx_notes/domain/sync/remote_document.dart';
import 'package:nx_notes/domain/sync/remote_save_result.dart';
import 'package:nx_notes/domain/sync/sync_failure.dart' as notes;
import 'package:nx_offline/nx_offline.dart' as offline;

const String _resolutionKey = 'notes.resolution';
const String _serverHashKey = 'notes.server_hash';
const String _remoteDocumentKey = 'notes.remote_document';
const String _writeResolution = 'write';
const String _createResolution = 'create';
const String _staleResolution = 'stale';

/// Adapts the typed Notes database outbox to the shared delivery runtime.
final class NotesOutboxStoreAdapter implements offline.OutboxStore {
  const NotesOutboxStoreAdapter({
    required this.localStore,
    required this.account,
  });

  final LocalNotesStore localStore;

  @override
  final offline.AccountIdentity account;

  @override
  Future<List<offline.PendingMutation>> pendingMutations() async {
    return <offline.PendingMutation>[
      for (final operation in await localStore.pendingOperations())
        _toShared(operation),
    ];
  }

  @override
  Future<offline.PendingMutation?> claimNext({
    required String workerId,
    required DateTime now,
    required Duration lease,
  }) async {
    final operation = await localStore.claimNextOperation(
      workerId: workerId,
      lease: lease,
      now: now,
    );
    return operation == null ? null : _toShared(operation);
  }

  @override
  Future<void> complete(offline.MutationReceipt receipt) async {
    final resolution = receipt.metadata[_resolutionKey];
    final remote = receipt.metadata[_remoteDocumentKey];
    if (resolution == _staleResolution && remote is RemoteDocument) {
      await localStore.discardStaleOperationAndImportRemote(
        receipt.operationId,
        remote,
      );
      return;
    }
    if (resolution == _createResolution && remote is RemoteDocument) {
      await localStore.completeCreateOperation(
        receipt.operationId,
        document: remote,
      );
      return;
    }
    await localStore.completeOperation(
      receipt.operationId,
      result: RemoteWriteResult(
        key: DocumentKey(
          localId: receipt.entityKey.localId,
          remoteId: receipt.entityKey.remoteId,
        ),
        revision: RemoteRevision(receipt.revision.value),
        serverHash: receipt.metadata[_serverHashKey] as String?,
      ),
    );
  }

  @override
  Future<void> fail(
    String operationId, {
    required offline.SyncFailure failure,
    required DateTime retryAt,
  }) {
    return localStore.failOperation(
      operationId,
      failure: notes.SyncFailure(
        kind: notes.SyncFailureKind.values.byName(failure.kind.name),
        message: failure.message,
      ),
      retryAt: retryAt,
    );
  }

  @override
  Future<DateTime?> nextRetryAt() async {
    DateTime? earliest;
    for (final operation in await localStore.pendingOperations()) {
      final retryAt = operation.nextAttemptAt;
      if (operation.status != PendingOperationStatus.retryWaiting ||
          retryAt == null) {
        continue;
      }
      if (earliest == null || retryAt.isBefore(earliest)) earliest = retryAt;
    }
    return earliest?.toUtc();
  }

  offline.PendingMutation _toShared(PendingOperation operation) {
    return offline.PendingMutation(
      operationId: operation.operationId,
      account: account,
      collection: DocumentMutationHandler.collectionName,
      entityKey: offline.EntityKey(
        localId: operation.documentKey.localId,
        remoteId: operation.documentKey.remoteId,
      ),
      type: offline.MutationType.values.byName(operation.type.name),
      payload: operation.payload,
      baseRevision: operation.baseRevision == null
          ? null
          : offline.Revision(operation.baseRevision!.value),
      createdAt: operation.createdAt,
      status: offline.PendingMutationStatus.values.byName(
        operation.status.name,
      ),
      attemptCount: operation.attemptCount,
      nextAttemptAt: operation.nextAttemptAt,
      leaseOwner: operation.leaseOwner,
      leaseExpiresAt: operation.leaseExpiresAt,
      lastError: operation.lastError,
    );
  }
}

/// Document-specific remote behavior used by the generic outbox processor.
final class DocumentMutationHandler implements offline.MutationHandler {
  const DocumentMutationHandler({
    required this.localStore,
    required this.remoteApi,
  });

  static const String collectionName = 'documents';

  final LocalNotesStore localStore;
  final NotesRemoteApi remoteApi;

  @override
  String get collection => collectionName;

  @override
  Future<offline.MutationReceipt> execute(
    offline.PendingMutation mutation,
  ) async {
    final key = DocumentKey(
      localId: mutation.entityKey.localId,
      remoteId: mutation.entityKey.remoteId,
    );
    final local = await localStore.getDocument(key);
    if (local == null) {
      throw offline.SyncTransportException(
        offline.SyncFailure(
          kind: offline.SyncFailureKind.validation,
          message: 'Pending document ${key.localId} is missing',
        ),
      );
    }

    return switch (mutation.type) {
      offline.MutationType.create => _create(mutation, local.document),
      offline.MutationType.update => _update(mutation, local.document),
      offline.MutationType.delete => _delete(mutation, local.document),
      offline.MutationType.relation =>
        throw const offline.SyncTransportException(
          offline.SyncFailure(
            kind: offline.SyncFailureKind.validation,
            message: 'Documents do not support relation outbox operations',
          ),
        ),
    };
  }

  Future<offline.MutationReceipt> _create(
    offline.PendingMutation mutation,
    NxDocument local,
  ) async {
    final created = await remoteApi.createDocument(
      title: local.title,
      kind: local.isBook ? DocumentKind.book : DocumentKind.document,
    );
    final remote = _remoteDocument(created);
    return _receipt(mutation, remote: remote, resolution: _createResolution);
  }

  Future<offline.MutationReceipt> _update(
    offline.PendingMutation mutation,
    NxDocument local,
  ) async {
    final result = await remoteApi.mutateDocument(local);
    if (result.status == RemoteSaveStatus.stale) {
      final remote = await remoteApi.fetchDocument(result.documentId);
      if (remote == null) {
        throw StateError(
          'Stale document ${result.documentId} no longer exists',
        );
      }
      return _receipt(
        mutation,
        remote: _remoteDocument(remote),
        resolution: _staleResolution,
      );
    }
    return offline.MutationReceipt(
      operationId: mutation.operationId,
      entityKey: mutation.entityKey.withRemoteId(result.documentId),
      revision: offline.Revision(result.updatedAt.toUtc().toIso8601String()),
      metadata: <String, Object?>{
        _resolutionKey: _writeResolution,
        _serverHashKey: result.serverHash,
      },
    );
  }

  Future<offline.MutationReceipt> _delete(
    offline.PendingMutation mutation,
    NxDocument local,
  ) async {
    final remoteId = mutation.entityKey.remoteId;
    if (remoteId != null) {
      final result = await remoteApi.deleteDocument(
        remoteId,
        clientUpdatedAt: mutation.createdAt,
      );
      if (result.status == RemoteSaveStatus.stale) {
        final remote = await remoteApi.fetchDocument(remoteId);
        if (remote == null) {
          throw StateError('Stale document $remoteId no longer exists');
        }
        return _receipt(
          mutation,
          remote: _remoteDocument(remote),
          resolution: _staleResolution,
        );
      }
    }
    return offline.MutationReceipt(
      operationId: mutation.operationId,
      entityKey: mutation.entityKey,
      revision: offline.Revision(local.updatedAt.toUtc().toIso8601String()),
      metadata: const <String, Object?>{_resolutionKey: _writeResolution},
    );
  }

  offline.MutationReceipt _receipt(
    offline.PendingMutation mutation, {
    required RemoteDocument remote,
    required String resolution,
  }) {
    return offline.MutationReceipt(
      operationId: mutation.operationId,
      entityKey: offline.EntityKey(
        localId: mutation.entityKey.localId,
        remoteId: remote.key.remoteId,
      ),
      revision: offline.Revision(remote.revision.value),
      metadata: <String, Object?>{
        _resolutionKey: resolution,
        _serverHashKey: remote.serverHash,
        _remoteDocumentKey: remote,
      },
    );
  }

  RemoteDocument _remoteDocument(NxDocument document) {
    return RemoteDocument(
      key: DocumentKey(localId: 'remote-${document.id}', remoteId: document.id),
      document: document,
      revision: RemoteRevision(document.updatedAt.toUtc().toIso8601String()),
    );
  }
}
