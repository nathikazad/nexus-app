import 'package:nx_docs/sync/native/background_uploader.dart';
import 'package:nx_docs/sync/native/local_notes_store.dart';
import 'package:nx_docs/sync/remote/document_remote_api.dart';
import 'package:nx_docs/sync/sync_models.dart';
import 'package:nx_offline/nx_offline.dart' as offline;

/// Coordinates native pull synchronization.
///
/// Cached reads stay local. Network work happens after the UI can render, and
/// every pull first gives the durable outbox a chance to upload local edits.
final class DocumentSynchronizer {
  DocumentSynchronizer({
    required LocalNotesStore localStore,
    required DocumentRemoteApi remoteApi,
    required BackgroundUploader uploader,
  }) : _localStore = localStore {
    _supervisor = offline.SyncSupervisor<int>(
      reconciler: _DocumentPullReconciler(
        localStore: localStore,
        remoteApi: remoteApi,
      ),
      prepare: uploader.uploadPending,
      coalescingWindow: Duration.zero,
    );
  }

  final LocalNotesStore _localStore;
  late final offline.SyncSupervisor<int> _supervisor;

  offline.SyncStatusSource get status => _supervisor;

  Future<void> syncLibrary({
    offline.SyncReason reason = offline.SyncReason.manual,
  }) {
    return _supervisor.requestFull(reason);
  }

  Future<void> requestDocuments(
    Iterable<int> documentIds, {
    offline.SyncReason reason = offline.SyncReason.foregroundDemand,
  }) {
    return _supervisor.requestKeys(documentIds, reason);
  }

  Future<LocalDocument?> refreshDocument(int documentId) async {
    await requestDocuments(<int>{documentId});
    return _localStore.getDocumentByRemoteId(documentId);
  }

  Future<void> close() => _supervisor.close();
}

final class _DocumentPullReconciler implements offline.PullReconciler<int> {
  const _DocumentPullReconciler({
    required LocalNotesStore localStore,
    required DocumentRemoteApi remoteApi,
  }) : _localStore = localStore,
       _remoteApi = remoteApi;

  final LocalNotesStore _localStore;
  final DocumentRemoteApi _remoteApi;

  @override
  Future<void> pullAll() async {
    final manifest = await _localStore.documentManifest();
    final bundle = await _remoteApi.syncDocuments(manifest: manifest);
    await _localStore.applySyncBundle(bundle);
  }

  @override
  Future<void> pullKeys(Set<int> keys) async {
    final eligibleIds = <int>{};
    final manifest = <DocumentManifestEntry>[];
    for (final documentId in keys) {
      final local = await _localStore.getDocumentByRemoteId(documentId);
      if (local != null && local.syncState != DocumentSyncState.synced) {
        continue;
      }
      eligibleIds.add(documentId);
      if (local != null) {
        manifest.add(
          DocumentManifestEntry(
            documentId: documentId,
            serverHash: local.serverHash,
          ),
        );
      }
    }
    if (eligibleIds.isEmpty) return;
    final bundle = await _remoteApi.syncDocuments(
      manifest: manifest,
      documentIds: eligibleIds,
    );
    await _localStore.applySyncBundle(bundle);
  }
}
