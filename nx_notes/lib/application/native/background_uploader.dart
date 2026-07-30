import 'dart:async';

import 'package:nx_notes/application/ports/clock.dart';
import 'package:nx_notes/application/ports/local_notes_store.dart';
import 'package:nx_notes/application/ports/notes_remote_api.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/sync/document_revision.dart';
import 'package:nx_notes/domain/sync/pending_operation.dart';
import 'package:nx_notes/domain/sync/remote_document.dart';
import 'package:nx_notes/domain/sync/remote_save_result.dart';
import 'package:nx_notes/domain/sync/sync_failure.dart';
import 'package:nx_offline/nx_offline.dart' as offline;

enum BackgroundUploadActivity { idle, uploading, retryWaiting }

final class BackgroundUploadState {
  const BackgroundUploadState({
    this.activity = BackgroundUploadActivity.idle,
    this.pendingCount = 0,
    this.lastUploadedAt,
    this.error,
  });

  final BackgroundUploadActivity activity;
  final int pendingCount;
  final DateTime? lastUploadedAt;
  final Object? error;
}

/// Drains the native durable outbox without performing catalog pulls.
final class BackgroundUploader {
  BackgroundUploader({
    required LocalNotesStore localStore,
    required NotesRemoteApi remoteApi,
    required Clock clock,
    required String workerId,
    this.uploadDelay = const Duration(seconds: 2),
    this.lease = const Duration(minutes: 1),
    this.retryPolicy = const offline.RetryPolicy(),
  }) : _localStore = localStore,
       _remoteApi = remoteApi,
       _clock = clock,
       _workerId = workerId;

  final LocalNotesStore _localStore;
  final NotesRemoteApi _remoteApi;
  final Clock _clock;
  final String _workerId;
  final Duration uploadDelay;
  final Duration lease;
  final offline.RetryPolicy retryPolicy;
  final StreamController<BackgroundUploadState> _states =
      StreamController<BackgroundUploadState>.broadcast(sync: true);

  BackgroundUploadState _state = const BackgroundUploadState();
  Future<void>? _activeUpload;
  Timer? _scheduledUpload;
  bool _closed = false;

  BackgroundUploadState get state => _state;
  Stream<BackgroundUploadState> get states => _states.stream;

  void schedule() {
    if (_closed) return;
    _scheduledUpload?.cancel();
    _scheduledUpload = Timer(uploadDelay, () => unawaited(uploadPending()));
  }

  Future<void> uploadPending() {
    if (_closed) return Future<void>.value();
    final active = _activeUpload;
    if (active != null) return active;
    final run = _drain();
    _activeUpload = run;
    return run.whenComplete(() {
      if (identical(_activeUpload, run)) _activeUpload = null;
    });
  }

  Future<void> _drain() async {
    _scheduledUpload?.cancel();
    _scheduledUpload = null;
    _emit(
      BackgroundUploadState(
        activity: BackgroundUploadActivity.uploading,
        pendingCount: (await _localStore.pendingOperations()).length,
        lastUploadedAt: _state.lastUploadedAt,
      ),
    );
    while (!_closed) {
      final operation = await _localStore.claimNextOperation(
        workerId: _workerId,
        lease: lease,
        now: _clock.now(),
      );
      if (operation == null) break;
      final shouldContinue = await _upload(operation);
      if (!shouldContinue) break;
    }
    final pendingCount = (await _localStore.pendingOperations()).length;
    _emit(
      BackgroundUploadState(
        activity: pendingCount == 0
            ? BackgroundUploadActivity.idle
            : BackgroundUploadActivity.retryWaiting,
        pendingCount: pendingCount,
        lastUploadedAt: _state.lastUploadedAt,
        error: pendingCount == 0 ? null : _state.error,
      ),
    );
  }

  Future<bool> _upload(PendingOperation operation) async {
    try {
      final local = await _localStore.getDocument(operation.documentKey);
      if (local == null) {
        throw StateError(
          'Pending document ${operation.documentKey.localId} is missing',
        );
      }
      switch (operation.type) {
        case PendingOperationType.create:
          final created = await _remoteApi.createDocument(
            title: local.document.title,
            kind: local.document.isBook
                ? DocumentKind.book
                : DocumentKind.document,
          );
          await _localStore.completeCreateOperation(
            operation.operationId,
            document: _remoteDocument(created),
          );
          break;
        case PendingOperationType.update:
          final result = await _remoteApi.mutateDocument(local.document);
          if (result.status == RemoteSaveStatus.applied) {
            await _localStore.completeOperation(
              operation.operationId,
              result: RemoteWriteResult(
                key: DocumentKey(
                  localId: operation.documentKey.localId,
                  remoteId: result.documentId,
                ),
                revision: RemoteRevision(
                  result.updatedAt.toUtc().toIso8601String(),
                ),
                serverHash: result.serverHash,
              ),
            );
          } else {
            final remote = await _remoteApi.fetchDocument(result.documentId);
            if (remote == null) {
              throw StateError(
                'Stale document ${result.documentId} no longer exists',
              );
            }
            await _localStore.discardStaleOperationAndImportRemote(
              operation.operationId,
              _remoteDocument(remote),
            );
          }
          break;
        case PendingOperationType.delete:
          final remoteId = operation.documentKey.remoteId;
          if (remoteId != null) {
            final result = await _remoteApi.deleteDocument(
              remoteId,
              clientUpdatedAt: operation.createdAt,
            );
            if (result.status == RemoteSaveStatus.stale) {
              final remote = await _remoteApi.fetchDocument(remoteId);
              if (remote == null) {
                throw StateError('Stale document $remoteId no longer exists');
              }
              await _localStore.discardStaleOperationAndImportRemote(
                operation.operationId,
                _remoteDocument(remote),
              );
              break;
            }
          }
          await _localStore.completeOperation(
            operation.operationId,
            result: RemoteWriteResult(
              key: operation.documentKey,
              revision: RemoteRevision(_clock.now().toUtc().toIso8601String()),
            ),
          );
          break;
      }
      _emit(
        BackgroundUploadState(
          activity: BackgroundUploadActivity.uploading,
          pendingCount: (await _localStore.pendingOperations()).length,
          lastUploadedAt: _clock.now(),
        ),
      );
      return true;
    } catch (error) {
      final retryAt = retryPolicy.retryAt(
        _clock.now(),
        operation.attemptCount + 1,
      );
      await _localStore.failOperation(
        operation.operationId,
        failure: SyncFailure(
          kind: SyncFailureKind.transient,
          message: error.toString(),
        ),
        retryAt: retryAt,
      );
      _emit(
        BackgroundUploadState(
          activity: BackgroundUploadActivity.retryWaiting,
          pendingCount: (await _localStore.pendingOperations()).length,
          lastUploadedAt: _state.lastUploadedAt,
          error: error,
        ),
      );
      return false;
    }
  }

  RemoteDocument _remoteDocument(NxDocument document) {
    return RemoteDocument(
      key: DocumentKey(localId: 'remote-${document.id}', remoteId: document.id),
      document: document,
      revision: RemoteRevision(document.updatedAt.toUtc().toIso8601String()),
    );
  }

  void _emit(BackgroundUploadState next) {
    _state = next;
    if (!_closed) _states.add(next);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _scheduledUpload?.cancel();
    await _activeUpload;
    await _states.close();
  }
}
