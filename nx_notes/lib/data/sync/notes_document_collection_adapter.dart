import 'package:nx_notes/application/ports/clock.dart';
import 'package:nx_notes/application/ports/local_notes_store.dart';
import 'package:nx_notes/application/sync/conflict_detector.dart';
import 'package:nx_notes/data/document/document_attr_keys.dart';
import 'package:nx_notes/data/sync/notes_sync_store_adapter.dart';
import 'package:nx_notes/data/sync/notes_sync_transport.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/sync/document_revision.dart';
import 'package:nx_notes/domain/sync/local_document.dart';
import 'package:nx_notes/domain/sync/remote_document.dart';
import 'package:nx_offline/nx_offline.dart' as offline;

/// Applies shared remote records to the existing Notes projection while
/// retaining Notes-specific conflict policy and stable local identities.
final class NotesDocumentCollectionAdapter
    implements offline.SyncCollectionAdapter {
  const NotesDocumentCollectionAdapter({
    required this.localStore,
    required this.account,
    required this.clock,
    this.documentCodec = const NotesSyncDocumentCodec(),
    this.pullResolutionPolicy = const PullResolutionPolicy(),
  });

  final LocalNotesStore localStore;
  final offline.AccountScope account;
  final Clock clock;
  final NotesSyncDocumentCodec documentCodec;
  final PullResolutionPolicy pullResolutionPolicy;

  @override
  String get collectionName => notesDocumentCollection;

  @override
  Set<String> get modelTypes => const {
    kDocumentModelTypeName,
    kBookModelTypeName,
  };

  @override
  Future<void> applyRemote(offline.RemoteRecord record) async {
    _validateRecord(record);
    final incomingKey = DocumentKey(
      localId: record.entityKey.localId,
      remoteId: record.entityKey.remoteId,
    );
    final existing = await _findExisting(incomingKey);
    final stableKey = existing?.key ?? incomingKey;
    final remote = RemoteDocument(
      key: stableKey,
      document: documentCodec.decode(notesRemoteDocumentPayload(record)),
      revision: RemoteRevision(record.revision.value),
      deleted: notesRemoteRecordIsDeleted(record),
    );
    final resolution = pullResolutionPolicy.resolve(
      localExists: existing != null,
      localState: existing?.syncState,
      baseRevision: existing?.baseServerRevision,
      incomingRevision: remote.revision,
    );

    switch (resolution) {
      case PullResolution.insertRemote:
      case PullResolution.replaceLocal:
        await localStore.importRemoteDocuments([remote]);
      case PullResolution.keepLocal:
        await localStore.mergeRemoteMetadata(remote);
        return;
      case PullResolution.conflict:
        await localStore.mergeRemoteMetadata(remote);
        throw offline.CollectionConflictException(
          offline.SyncConflict(
            account: account,
            collection: collectionName,
            entityKey: offline.EntityKey(
              localId: existing!.key.localId,
              remoteId: existing.key.remoteId,
            ),
            localPayload: documentCodec.encode(existing.document),
            remotePayload: documentCodec.encode(remote.document),
            remoteRevision: record.revision,
            detectedAt: clock.now(),
          ),
        );
    }
  }

  @override
  Future<void> applyTombstone(offline.RemoteTombstone tombstone) async {
    if (tombstone.collection != collectionName) {
      throw StateError('unsupported Notes collection: ${tombstone.collection}');
    }
    final key = DocumentKey(
      localId: tombstone.entityKey.localId,
      remoteId: tombstone.entityKey.remoteId,
    );
    final existing = await _findExisting(key);
    if (existing == null) return;
    await localStore.importRemoteDocuments([
      RemoteDocument(
        key: existing.key,
        document: existing.document,
        revision: RemoteRevision(tombstone.revision.value),
        deleted: true,
      ),
    ]);
  }

  @override
  Future<void> preserveConflict(offline.RemoteRecord remote) async {
    // SyncStore.recordConflict already durably stores both complete documents.
  }

  Future<LocalDocument?> _findExisting(DocumentKey key) async {
    final byLocal = await localStore.getDocument(key);
    if (byLocal != null || key.remoteId == null) return byLocal;
    return localStore.getDocumentByRemoteId(key.remoteId!);
  }

  void _validateRecord(offline.RemoteRecord record) {
    if (record.collection != collectionName) {
      throw StateError('unsupported Notes collection: ${record.collection}');
    }
    if (!modelTypes.contains(record.modelType)) {
      throw StateError('unsupported Notes model type: ${record.modelType}');
    }
  }
}
