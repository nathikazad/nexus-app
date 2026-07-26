import 'package:nx_notes/application/ports/local_notes_store.dart';
import 'package:nx_notes/application/ports/remote_document_gateway.dart';
import 'package:nx_notes/data/sync/notes_sync_store_adapter.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/sync/document_revision.dart';
import 'package:nx_notes/domain/sync/local_document.dart';
import 'package:nx_notes/domain/sync/sync_failure.dart' as notes;
import 'package:nx_offline/nx_offline.dart' as offline;

const String _deletedPayloadKey = r'$notes_deleted';

/// Maps the existing typed Notes gateway to the shared transport boundary.
///
/// The durable Notes outbox intentionally remains the source of mutation
/// identity while the current local projection supplies the complete document
/// required by create and update requests.
final class NotesSyncTransport implements offline.SyncTransport {
  const NotesSyncTransport({
    required this.localStore,
    required this.remoteGateway,
    required this.account,
    this.documentCodec = const NotesSyncDocumentCodec(),
  });

  final LocalNotesStore localStore;
  final RemoteDocumentGateway remoteGateway;
  final offline.AccountScope account;
  final NotesSyncDocumentCodec documentCodec;

  @override
  Future<offline.MutationReceipt> push(offline.PendingMutation mutation) async {
    _validateMutation(mutation);
    final local = await _findLocal(mutation.entityKey);
    if (local == null) {
      throw const offline.SyncTransportException(
        offline.SyncFailure(
          kind: offline.SyncFailureKind.validation,
          message: 'local document does not exist',
        ),
      );
    }

    try {
      final result = await (switch (mutation.type) {
        offline.MutationType.create => remoteGateway.createDocument(
          RemoteCreateRequest(key: local.key, document: local.document),
          idempotencyKey: mutation.operationId,
        ),
        offline.MutationType.update => remoteGateway.updateDocument(
          RemoteUpdateRequest(key: local.key, document: local.document),
          idempotencyKey: mutation.operationId,
          expectedRevision: _requiredRevision(
            mutation,
            local.baseServerRevision,
          ),
        ),
        offline.MutationType.delete => remoteGateway.deleteDocument(
          RemoteDeleteRequest(key: local.key),
          idempotencyKey: mutation.operationId,
          expectedRevision: _requiredRevision(
            mutation,
            local.baseServerRevision,
          ),
        ),
        offline.MutationType.relation =>
          throw const offline.SyncTransportException(
            offline.SyncFailure(
              kind: offline.SyncFailureKind.validation,
              message: 'Notes does not support standalone relation mutations',
            ),
          ),
      });
      return offline.MutationReceipt(
        operationId: mutation.operationId,
        entityKey: offline.EntityKey(
          localId: result.key.localId,
          remoteId: result.key.remoteId,
        ),
        revision: offline.Revision(result.revision.value),
      );
    } on RemoteGatewayException catch (error) {
      throw offline.SyncTransportException(_toOfflineFailure(error.failure));
    }
  }

  @override
  Future<offline.RemoteChangePage> pull({
    required offline.AccountScope account,
    required String collection,
    required Set<String> modelTypes,
    required offline.SyncCursor? cursor,
  }) async {
    if (account != this.account) {
      throw StateError('pull belongs to another account');
    }
    if (collection != notesDocumentCollection) {
      throw StateError('unsupported Notes collection: $collection');
    }

    try {
      final changes = await remoteGateway.pullChanges(cursor: cursor?.value);
      return offline.RemoteChangePage(
        records: [
          for (final remote in changes.documents)
            offline.RemoteRecord(
              collection: collection,
              modelType: remote.document.modelTypeName,
              entityKey: offline.EntityKey(
                localId: remote.key.localId,
                remoteId: remote.key.remoteId,
              ),
              revision: offline.Revision(remote.revision.value),
              payload: <String, Object?>{
                ...documentCodec.encode(remote.document),
                _deletedPayloadKey: remote.deleted,
              },
            ),
        ],
        tombstones: const [],
        nextCursor: offline.SyncCursor(changes.nextCursor),
      );
    } on RemoteGatewayException catch (error) {
      throw offline.SyncTransportException(_toOfflineFailure(error.failure));
    }
  }

  Future<LocalDocument?> _findLocal(offline.EntityKey key) async {
    final byLocal = await localStore.getDocument(
      DocumentKey(localId: key.localId, remoteId: key.remoteId),
    );
    if (byLocal != null || key.remoteId == null) return byLocal;
    return localStore.getDocumentByRemoteId(key.remoteId!);
  }

  RemoteRevision _requiredRevision(
    offline.PendingMutation mutation,
    RemoteRevision? localBaseRevision,
  ) {
    final revision = mutation.baseRevision?.value ?? localBaseRevision?.value;
    if (revision == null) {
      throw const offline.SyncTransportException(
        offline.SyncFailure(
          kind: offline.SyncFailureKind.validation,
          message: 'mutation is missing its base remote revision',
        ),
      );
    }
    return RemoteRevision(revision);
  }

  void _validateMutation(offline.PendingMutation mutation) {
    if (mutation.account != account) {
      throw StateError('mutation belongs to another account');
    }
    if (mutation.collection != notesDocumentCollection) {
      throw StateError('unsupported Notes collection: ${mutation.collection}');
    }
  }
}

bool notesRemoteRecordIsDeleted(offline.RemoteRecord record) =>
    record.payload[_deletedPayloadKey] == true;

Map<String, Object?> notesRemoteDocumentPayload(offline.RemoteRecord record) {
  return Map<String, Object?>.from(record.payload)..remove(_deletedPayloadKey);
}

offline.SyncFailure _toOfflineFailure(notes.SyncFailure failure) {
  return offline.SyncFailure(
    kind: offline.SyncFailureKind.values.byName(failure.kind.name),
    message: failure.message,
  );
}
