import 'dart:convert';

import 'package:nx_notes/application/ports/local_notes_store.dart';
import 'package:nx_notes/data/local/drift/drift_document_mapper.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/sync/document_revision.dart';
import 'package:nx_notes/domain/sync/pending_operation.dart';
import 'package:nx_notes/domain/sync/remote_document.dart';
import 'package:nx_notes/domain/sync/sync_conflict.dart' as notes_conflict;
import 'package:nx_notes/domain/sync/sync_failure.dart' as notes_failure;
import 'package:nx_offline/nx_offline.dart' as offline;

const String notesDocumentCollection = 'documents';

/// Adapts the existing Notes store to the shared synchronization contract.
///
/// The adapter deliberately keeps using [LocalNotesStore]. It does not create
/// an `nx_offline` database, rename the Notes database, or rewrite existing
/// document/outbox/cursor/conflict rows.
final class NotesSyncStoreAdapter implements offline.SyncStore {
  NotesSyncStoreAdapter({
    required this.delegate,
    required this.account,
    this.documentCodec = const NotesSyncDocumentCodec(),
  }) {
    final expectedKey = '${account.backend}:${account.userId}';
    if (delegate.accountKey != expectedKey) {
      throw StateError(
        'Notes store account ${delegate.accountKey} does not match '
        'shared account $expectedKey',
      );
    }
  }

  final LocalNotesStore delegate;

  @override
  final offline.AccountScope account;

  final NotesSyncDocumentCodec documentCodec;

  @override
  Future<void> enqueue(offline.PendingMutation mutation) async {
    _validateMutation(mutation);
    final documentKey = _toNotesKey(mutation.entityKey);
    final document = await delegate.getDocument(documentKey);
    if (document == null) {
      throw StateError(
        'cannot enqueue ${mutation.operationId}: local document not found',
      );
    }
    await delegate.saveDraftAndEnqueue(
      document,
      operation: _toNotesOperation(mutation),
    );
  }

  @override
  Future<List<offline.PendingMutation>> pendingMutations() async {
    return (await delegate.pendingOperations())
        .map(_toOfflineMutation)
        .toList(growable: false);
  }

  @override
  Future<offline.PendingMutation?> claimNext({
    required String workerId,
    required DateTime now,
    required Duration lease,
  }) async {
    final operation = await delegate.claimNextOperation(
      workerId: workerId,
      lease: lease,
      now: now,
    );
    return operation == null ? null : _toOfflineMutation(operation);
  }

  @override
  Future<void> complete(offline.MutationReceipt receipt) {
    return delegate.completeOperation(
      receipt.operationId,
      result: RemoteWriteResult(
        key: _toNotesKey(receipt.entityKey),
        revision: RemoteRevision(receipt.revision.value),
      ),
    );
  }

  @override
  Future<void> fail(
    String operationId, {
    required offline.SyncFailure failure,
    required DateTime retryAt,
  }) {
    return delegate.failOperation(
      operationId,
      failure: notes_failure.SyncFailure(
        kind: _toNotesFailureKind(failure.kind),
        message: failure.message,
      ),
      retryAt: retryAt,
    );
  }

  @override
  Future<offline.SyncCursor?> readCursor(String collection) async {
    _validateCollection(collection);
    final cursor = await delegate.readSyncCursor();
    return cursor == null ? null : offline.SyncCursor(cursor);
  }

  @override
  Future<void> writeCursor(String collection, offline.SyncCursor cursor) {
    _validateCollection(collection);
    return delegate.writeSyncCursor(cursor.value);
  }

  @override
  Future<void> recordConflict(offline.SyncConflict conflict) {
    _validateCollection(conflict.collection);
    if (conflict.account != account) {
      throw StateError('conflict belongs to another account');
    }
    return delegate.recordConflict(
      notes_conflict.SyncConflict(
        documentKey: _toNotesKey(conflict.entityKey),
        localDocument: documentCodec.decode(conflict.localPayload),
        remoteDocument: documentCodec.decode(conflict.remotePayload),
        remoteRevision: RemoteRevision(conflict.remoteRevision.value),
        detectedAt: conflict.detectedAt,
      ),
    );
  }

  offline.PendingMutation _toOfflineMutation(PendingOperation operation) {
    return offline.PendingMutation(
      operationId: operation.operationId,
      account: account,
      collection: notesDocumentCollection,
      entityKey: _toOfflineKey(operation.documentKey),
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

  PendingOperation _toNotesOperation(offline.PendingMutation mutation) {
    if (mutation.type == offline.MutationType.relation) {
      throw StateError(
        'the current Notes outbox does not store relation mutations',
      );
    }
    if (mutation.operationGroup != null) {
      throw StateError(
        'the current Notes outbox does not store operation groups',
      );
    }
    return PendingOperation(
      operationId: mutation.operationId,
      accountKey: delegate.accountKey,
      documentKey: _toNotesKey(mutation.entityKey),
      type: PendingOperationType.values.byName(mutation.type.name),
      payload: mutation.payload,
      baseRevision: mutation.baseRevision == null
          ? null
          : RemoteRevision(mutation.baseRevision!.value),
      createdAt: mutation.createdAt,
      status: PendingOperationStatus.values.byName(mutation.status.name),
      attemptCount: mutation.attemptCount,
      nextAttemptAt: mutation.nextAttemptAt,
      leaseOwner: mutation.leaseOwner,
      leaseExpiresAt: mutation.leaseExpiresAt,
      lastError: mutation.lastError,
    );
  }

  void _validateMutation(offline.PendingMutation mutation) {
    _validateCollection(mutation.collection);
    if (mutation.account != account) {
      throw StateError('mutation belongs to another account');
    }
  }

  void _validateCollection(String collection) {
    if (collection != notesDocumentCollection) {
      throw StateError('unsupported Notes collection: $collection');
    }
  }
}

final class NotesSyncDocumentCodec {
  const NotesSyncDocumentCodec({this.mapper = const DriftDocumentMapper()});

  final DriftDocumentMapper mapper;

  Map<String, Object?> encode(NxDocument document) {
    return Map<String, Object?>.from(
      jsonDecode(mapper.documentToJsonString(document)) as Map,
    );
  }

  NxDocument decode(Map<String, Object?> payload) {
    return mapper.documentFromJsonString(jsonEncode(payload));
  }
}

offline.EntityKey _toOfflineKey(DocumentKey key) {
  return offline.EntityKey(localId: key.localId, remoteId: key.remoteId);
}

DocumentKey _toNotesKey(offline.EntityKey key) {
  return DocumentKey(localId: key.localId, remoteId: key.remoteId);
}

notes_failure.SyncFailureKind _toNotesFailureKind(
  offline.SyncFailureKind kind,
) {
  return switch (kind) {
    offline.SyncFailureKind.transient =>
      notes_failure.SyncFailureKind.transient,
    offline.SyncFailureKind.authentication =>
      notes_failure.SyncFailureKind.authentication,
    offline.SyncFailureKind.conflict => notes_failure.SyncFailureKind.conflict,
    offline.SyncFailureKind.validation =>
      notes_failure.SyncFailureKind.validation,
    offline.SyncFailureKind.unknown => notes_failure.SyncFailureKind.unknown,
  };
}
