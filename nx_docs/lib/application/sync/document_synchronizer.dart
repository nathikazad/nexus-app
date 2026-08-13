import 'package:nx_docs/application/native/background_uploader.dart';
import 'package:nx_docs/application/ports/local_notes_store.dart';
import 'package:nx_docs/application/ports/notes_remote_api.dart';
import 'package:nx_docs/domain/sync/document_sync.dart';
import 'package:nx_docs/domain/sync/local_document.dart';
import 'package:nx_docs/domain/sync/sync_state.dart';
import 'package:nx_offline/nx_offline.dart' as offline;

/// Coordinates native pull synchronization.
///
/// Cached reads stay local. Network work happens after the UI can render, and
/// every pull first gives the durable outbox a chance to upload local edits.
final class DocumentSynchronizer {
  DocumentSynchronizer({
    required LocalNotesStore localStore,
    required NotesRemoteApi remoteApi,
    required BackgroundUploader uploader,
  }) : _localStore = localStore,
       _remoteApi = remoteApi,
       _uploader = uploader;

  final LocalNotesStore _localStore;
  final NotesRemoteApi _remoteApi;
  final BackgroundUploader _uploader;
  final offline.ReconciliationCoordinator<int, LocalDocument?> _runs =
      offline.ReconciliationCoordinator<int, LocalDocument?>();

  Future<void> syncLibrary() => _runs.runFull(_syncLibraryOnce);

  Future<void> _syncLibraryOnce() async {
    await _uploader.uploadPending();
    final manifest = await _localStore.documentManifest();
    final bundle = await _remoteApi.syncDocuments(manifest: manifest);
    await _localStore.applySyncBundle(bundle);
  }

  Future<LocalDocument?> refreshDocument(int documentId) => _runs.runItem(
    documentId,
    reconcile: () => _refreshDocumentOnce(documentId),
    readAfterFull: () => _localStore.getDocumentByRemoteId(documentId),
  );

  Future<LocalDocument?> _refreshDocumentOnce(int documentId) async {
    await _uploader.uploadPending();
    final local = await _localStore.getDocumentByRemoteId(documentId);
    if (local != null && local.syncState != DocumentSyncState.synced) {
      return local;
    }
    final bundle = await _remoteApi.syncDocuments(
      manifest: local == null
          ? const <DocumentManifestEntry>[]
          : <DocumentManifestEntry>[
              DocumentManifestEntry(
                documentId: documentId,
                serverHash: local.serverHash,
              ),
            ],
      documentIds: <int>{documentId},
    );
    await _localStore.applySyncBundle(bundle);
    return _localStore.getDocumentByRemoteId(documentId);
  }
}
