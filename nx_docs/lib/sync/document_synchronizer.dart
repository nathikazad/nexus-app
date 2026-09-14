import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:nx_docs/sync/native/background_uploader.dart';
import 'package:nx_docs/sync/storage_profile.dart';
import 'package:nx_docs/sync/native/local_notes_store.dart';
import 'package:nx_docs/sync/remote/document_remote_api.dart';
import 'package:nx_docs/sync/sync_models.dart';
import 'package:nx_offline/nx_offline.dart' as offline;

/// Shared manifest reconciliation, with an independent foreground lane.
/// Compare-and-set imports prevent either lane from overwriting a newer save.
final class DocumentSynchronizer {
  DocumentSynchronizer({
    required LocalNotesStore localStore,
    required DocumentRemoteApi remoteApi,
    required BackgroundUploader uploader,
  }) : _localStore = localStore,
       _uploader = uploader {
    final reconciler = _DocumentPullReconciler(
      localStore: localStore,
      remoteApi: remoteApi,
      report: _report,
    );
    _supervisor = offline.SyncSupervisor<int>(
      reconciler: reconciler,
      coalescingWindow: Duration.zero,
      retryDelay: const Duration(seconds: 5),
    );
    _foreground = offline.SyncSupervisor<int>(
      reconciler: reconciler,
      coalescingWindow: Duration.zero,
    );
  }

  final LocalNotesStore _localStore;
  final BackgroundUploader _uploader;
  late final offline.SyncSupervisor<int> _supervisor;
  late final offline.SyncSupervisor<int> _foreground;
  final _reports = StreamController<offline.DownloadReport>.broadcast(
    sync: true,
  );
  offline.DownloadReport? _progress;
  bool _closed = false;

  offline.SyncStatusSource get status => _supervisor;
  offline.DownloadReport? get progress => _progress;
  Stream<offline.DownloadReport> get progressChanges => _reports.stream;

  void _report(offline.DownloadReport value) {
    _progress = value;
    debugPrint(
      '[NX Docs sync] ${value.phase.name} ${value.verified}/${value.total} at ${value.updatedAt.toIso8601String()}',
    );
    if (!_closed) _reports.add(value);
  }

  void _uploadInBackground() {
    unawaited(_uploader.uploadPending().catchError((Object _) {}));
  }

  Future<void> syncLibrary({
    offline.SyncReason reason = offline.SyncReason.manual,
  }) {
    _uploadInBackground();
    return _supervisor.requestFull(reason);
  }

  Future<void> requestDocuments(
    Iterable<int> documentIds, {
    offline.SyncReason reason = offline.SyncReason.foregroundDemand,
  }) {
    _uploadInBackground();
    return _foreground.requestKeys(documentIds, reason);
  }

  Future<LocalDocument?> refreshDocument(int documentId) async {
    await requestDocuments(<int>{documentId});
    return _localStore.getDocumentByRemoteId(documentId);
  }

  Future<void> close() async {
    _closed = true;
    await Future.wait([_supervisor.close(), _foreground.close()]);
    await _reports.close();
  }
}

final class _DocumentPullReconciler implements offline.PullReconciler<int> {
  const _DocumentPullReconciler({
    required LocalNotesStore localStore,
    required DocumentRemoteApi remoteApi,
    required void Function(offline.DownloadReport) report,
  }) : _localStore = localStore,
       _remoteApi = remoteApi,
       _report = report;

  final LocalNotesStore _localStore;
  final DocumentRemoteApi _remoteApi;
  final void Function(offline.DownloadReport) _report;

  @override
  Future<void> pullAll() async {
    var total = 0;
    var verified = 0;
    var failed = <String>[];
    void report(offline.DownloadPhase phase) => _report(
      offline.DownloadReport(
        phase: phase,
        total: total,
        verified: verified,
        failed: List.unmodifiable(failed),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    report(offline.DownloadPhase.checking);
    try {
      final local = await _localStore.documentManifest();
      final base = {
        for (final entry in local) entry.documentId: entry.serverHash,
      };
      recordStorageMemory('before_download', documents: local.length);
      final remote = await _remoteApi.syncDocuments(
        manifest: const [],
        manifestOnly: true,
      );
      final active = await offline
          .reconcileHashManifest<int, DocumentManifestEntry, RemoteDocument>(
            manifest: remote.manifest,
            downloadPageSize: 20,
            keyOf: (entry) => entry.documentId,
            valueKeyOf: (document) => document.key.remoteId!,
            verified: _localStore.hasCurrentDocument,
            download: (ids) async {
              final bundle = await _remoteApi.syncDocuments(
                // Force a body for damaged/missing local files even if hashes match.
                manifest: [
                  for (final id in ids) DocumentManifestEntry(documentId: id),
                ],
                documentIds: ids,
              );
              return offline.HashDownload(
                bundle.documents,
                deleted: bundle.deletedIds.toSet(),
              );
            },
            applyBatch: (documents) async {
              await _localStore.applySyncBundle(
                DocumentSyncBundle(
                  documents: documents,
                  expectedHashes: {
                    for (final doc in documents)
                      doc.key.remoteId!: base[doc.key.remoteId],
                  },
                ),
              );
              return <int>[];
            },
            report: (downloading, count, done, failures) async {
              total = count;
              verified = done;
              failed = failures.map((id) => '$id').toList();
              report(
                downloading
                    ? offline.DownloadPhase.downloading
                    : offline.DownloadPhase.checking,
              );
            },
          );
      final activeIds = active.map((entry) => entry.documentId).toSet();
      await _localStore.applySyncBundle(
        DocumentSyncBundle(
          deletedIds: base.keys.where((id) => !activeIds.contains(id)).toList(),
          expectedHashes: base,
        ),
      );
      report(offline.DownloadPhase.complete);
      recordStorageMemory(
        'after_download',
        documents: total,
        downloaded: verified,
      );
    } catch (_) {
      report(offline.DownloadPhase.incomplete);
      rethrow;
    }
  }

  @override
  Future<void> pullKeys(Set<int> keys) async {
    final eligibleIds = <int>{};
    final manifest = <DocumentManifestEntry>[];
    final base = <int, String?>{};
    for (final id in keys) {
      final local = await _localStore.getDocumentByRemoteId(id);
      if (local != null && local.syncState != DocumentSyncState.synced) {
        continue;
      }
      eligibleIds.add(id);
      base[id] = local?.serverHash;
      if (local != null) {
        manifest.add(
          DocumentManifestEntry(documentId: id, serverHash: local.serverHash),
        );
      }
    }
    if (eligibleIds.isEmpty) return;
    final bundle = await _remoteApi.syncDocuments(
      manifest: manifest,
      documentIds: eligibleIds,
    );
    await _localStore.applySyncBundle(
      DocumentSyncBundle(
        documents: bundle.documents,
        deletedIds: bundle.deletedIds,
        expectedHashes: base,
      ),
    );
  }
}
