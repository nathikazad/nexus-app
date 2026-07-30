import 'package:nx_notes/application/native/background_uploader.dart';
import 'package:nx_notes/application/ports/local_notes_store.dart';
import 'package:nx_notes/application/ports/notes_remote_api.dart';
import 'package:nx_notes/domain/sync/document_sync.dart';
import 'package:nx_notes/domain/sync/local_document.dart';
import 'package:nx_notes/domain/sync/sync_state.dart';

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
  final Map<int, Future<LocalDocument?>> _documentRuns =
      <int, Future<LocalDocument?>>{};
  Future<void>? _libraryRun;

  Future<void> syncLibrary() {
    final active = _libraryRun;
    if (active != null) return active;
    final run = _syncLibraryOnce();
    _libraryRun = run;
    return run.whenComplete(() {
      if (identical(_libraryRun, run)) _libraryRun = null;
    });
  }

  Future<void> _syncLibraryOnce() async {
    await _uploader.uploadPending();
    final manifest = await _localStore.documentManifest();
    final bundle = await _remoteApi.syncDocuments(manifest: manifest);
    await _localStore.applySyncBundle(bundle);
  }

  Future<LocalDocument?> refreshDocument(int documentId) {
    final active = _documentRuns[documentId];
    if (active != null) return active;
    final run = _refreshDocumentOnce(documentId);
    _documentRuns[documentId] = run;
    return run.whenComplete(() {
      if (identical(_documentRuns[documentId], run)) {
        _documentRuns.remove(documentId);
      }
    });
  }

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
