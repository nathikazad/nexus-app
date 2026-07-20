import 'package:nx_notes/application/ports/clock.dart';
import 'package:nx_notes/application/ports/id_generator.dart';
import 'package:nx_notes/application/ports/local_notes_store.dart';
import 'package:nx_notes/application/sync/document_sync_engine.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/document/document_query.dart';
import 'package:nx_notes/domain/sync/document_revision.dart';
import 'package:nx_notes/domain/sync/local_document.dart';
import 'package:nx_notes/domain/sync/pending_operation.dart';
import 'package:nx_notes/domain/sync/remote_document.dart';
import 'package:nx_notes/domain/sync/sync_state.dart';
import 'package:nx_notes/domain/sync/sync_status.dart';

class OfflineNotesService {
  const OfflineNotesService({
    required this.localStore,
    required this.syncEngine,
    required this.clock,
    required this.idGenerator,
  });

  final LocalNotesStore localStore;
  final DocumentSyncEngine syncEngine;
  final Clock clock;
  final IdGenerator idGenerator;

  Stream<List<LocalDocument>> watchDocuments(DocumentQuery query) =>
      localStore.watchDocuments(query);

  Stream<LocalDocument?> watchDocument(DocumentKey key) =>
      localStore.watchDocument(key);

  Future<LocalDocument?> getDocument(DocumentKey key) =>
      localStore.getDocument(key);

  SyncStatus get syncStatus => syncEngine.status;
  Stream<SyncStatus> get syncStatusChanges => syncEngine.statusChanges;

  Future<void> importRemoteDocuments(List<RemoteDocument> documents) =>
      localStore.importRemoteDocuments(documents);

  Future<LocalDocument> saveDraft(LocalDocument document) async {
    final existing = await localStore.getDocument(document.key);
    final operationType = document.key.remoteId == null
        ? PendingOperationType.create
        : PendingOperationType.update;
    final operation = PendingOperation(
      operationId: idGenerator.nextId(),
      accountKey: localStore.accountKey,
      documentKey: document.key,
      type: operationType,
      payload: <String, Object?>{'document': document.document.document},
      baseRevision: existing?.baseServerRevision ?? document.baseServerRevision,
      createdAt: clock.now(),
    );
    final saved = document.copyWith(
      accountKey: localStore.accountKey,
      localUpdatedAt: clock.now(),
      syncState: DocumentSyncState.locallyModified,
    );
    await localStore.saveDraftAndEnqueue(saved, operation: operation);
    return (await localStore.getDocument(saved.key))!;
  }

  Future<LocalDocument> saveRemoteDraft(NxDocument document) async {
    final key = DocumentKey(
      localId: 'remote-${document.id}',
      remoteId: document.id,
    );
    final existing = await localStore.getDocument(key);
    final observedRevision = RemoteRevision(
      document.updatedAt.toUtc().toIso8601String(),
    );
    return saveDraft(
      LocalDocument(
        key: key,
        accountKey: localStore.accountKey,
        document: document,
        localUpdatedAt: clock.now(),
        serverRevision: existing?.serverRevision ?? observedRevision,
        baseServerRevision: existing?.baseServerRevision ?? observedRevision,
        syncState: DocumentSyncState.locallyModified,
      ),
    );
  }

  Future<LocalDocument> createDraft(NxDocument document) {
    return saveDraft(
      LocalDocument(
        key: DocumentKey(localId: idGenerator.nextId()),
        accountKey: localStore.accountKey,
        document: document,
        localUpdatedAt: clock.now(),
        syncState: DocumentSyncState.locallyModified,
      ),
    );
  }

  Future<void> deleteDraft(LocalDocument document) async {
    final deleted = document.copyWith(
      deletedLocally: true,
      localUpdatedAt: clock.now(),
      syncState: DocumentSyncState.locallyModified,
    );
    await localStore.saveDraftAndEnqueue(
      deleted,
      operation: PendingOperation(
        operationId: idGenerator.nextId(),
        accountKey: localStore.accountKey,
        documentKey: deleted.key,
        type: PendingOperationType.delete,
        payload: const <String, Object?>{},
        baseRevision: deleted.baseServerRevision,
        createdAt: clock.now(),
      ),
    );
  }

  Future<SyncRunResult> synchronize({SyncReason reason = SyncReason.manual}) =>
      syncEngine.synchronize(reason: reason);
}
