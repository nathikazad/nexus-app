import 'dart:async';

import 'package:nx_notes/application/document_session.dart';
import 'package:nx_notes/application/native/background_uploader.dart';
import 'package:nx_notes/application/ports/clock.dart';
import 'package:nx_notes/application/ports/id_generator.dart';
import 'package:nx_notes/application/ports/local_notes_store.dart';
import 'package:nx_notes/application/sync/document_synchronizer.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/sync/document_revision.dart';
import 'package:nx_notes/domain/sync/local_document.dart';
import 'package:nx_notes/domain/sync/pending_operation.dart';
import 'package:nx_notes/domain/sync/sync_state.dart';

final class NativeDocumentSession implements DocumentSession {
  NativeDocumentSession({
    required this.documentId,
    required LocalNotesStore localStore,
    required DocumentSynchronizer synchronizer,
    required BackgroundUploader uploader,
    required Clock clock,
    required IdGenerator idGenerator,
    void Function()? onClosed,
  }) : _localStore = localStore,
       _synchronizer = synchronizer,
       _uploader = uploader,
       _clock = clock,
       _idGenerator = idGenerator,
       _onClosed = onClosed {
    unawaited(_start());
  }

  @override
  final int documentId;
  final LocalNotesStore _localStore;
  final DocumentSynchronizer _synchronizer;
  final BackgroundUploader _uploader;
  final Clock _clock;
  final IdGenerator _idGenerator;
  final void Function()? _onClosed;
  final StreamController<DocumentSessionState> _states =
      StreamController<DocumentSessionState>.broadcast(sync: true);

  DocumentSessionState _state = const DocumentSessionState();
  StreamSubscription<LocalDocument?>? _localSubscription;
  Future<void>? _activeRefresh;
  DocumentChangeOrigin _nextLocalOrigin = DocumentChangeOrigin.localCache;
  bool _closed = false;

  DocumentKey get _key =>
      DocumentKey(localId: 'remote-$documentId', remoteId: documentId);

  @override
  DocumentSessionState get state => _state;

  @override
  Stream<DocumentSessionState> get states => _states.stream;

  Future<void> _start() async {
    final cached = await _localStore.getDocumentByRemoteId(documentId);
    if (_closed) return;
    _applyLocal(cached);
    _localSubscription = _localStore
        .watchDocument(cached?.key ?? _key)
        .listen(
          _applyLocal,
          onError: (Object error, StackTrace stackTrace) {
            _emit(_state.copyWith(error: error));
          },
        );
    await refresh();
  }

  void _applyLocal(LocalDocument? local) {
    if (_closed || local == null) return;
    final origin = _nextLocalOrigin;
    _nextLocalOrigin = DocumentChangeOrigin.localCache;
    final hasBody = local.document.hasFullDocument;
    _emit(
      _state.copyWith(
        phase: hasBody ? DocumentPhase.ready : _state.phase,
        document: hasBody ? local.document : _state.document,
        uploadState: _uploadState(local.syncState),
        origin: origin,
        clearError: true,
      ),
    );
  }

  @override
  Future<void> refresh() {
    final active = _activeRefresh;
    if (active != null) return active;
    final run = _refreshOnce();
    _activeRefresh = run;
    return run.whenComplete(() {
      if (identical(_activeRefresh, run)) _activeRefresh = null;
    });
  }

  Future<void> _refreshOnce() async {
    if (_closed) return;
    _emit(_state.copyWith(isRefreshing: true, clearError: true));
    try {
      final cached = await _localStore.getDocumentByRemoteId(documentId);
      _nextLocalOrigin = cached == null
          ? DocumentChangeOrigin.initialRemoteLoad
          : DocumentChangeOrigin.remoteRefresh;
      final refreshed = await _synchronizer.refreshDocument(documentId);
      if (_closed) return;
      if (refreshed == null) {
        _emit(
          _state.copyWith(
            phase: _state.document == null
                ? DocumentPhase.notFound
                : DocumentPhase.ready,
            isRefreshing: false,
          ),
        );
        return;
      }
      _applyLocal(refreshed);
      _emit(_state.copyWith(isRefreshing: false, clearError: true));
    } catch (error) {
      if (_closed) return;
      _emit(
        _state.copyWith(
          phase: _state.document == null
              ? DocumentPhase.unavailableOffline
              : DocumentPhase.ready,
          isRefreshing: false,
          error: error,
        ),
      );
    }
  }

  @override
  Future<void> saveDraft(NxDocument document) async {
    if (_closed) throw StateError('Document session is closed');
    final existing = await _localStore.getDocumentByRemoteId(documentId);
    final now = _clock.now();
    final editTime =
        existing != null && !now.isAfter(existing.document.updatedAt)
        ? existing.document.updatedAt.add(const Duration(microseconds: 1))
        : now;
    final edited = document.copyWith(
      updatedAt: editTime,
      updatedLabel: 'just now',
    );
    final key = existing?.key ?? _key;
    final observedRevision =
        existing?.serverRevision ??
        RemoteRevision(document.updatedAt.toUtc().toIso8601String());
    final local = LocalDocument(
      key: key,
      accountKey: _localStore.accountKey,
      document: edited,
      localUpdatedAt: editTime,
      serverRevision: observedRevision,
      baseServerRevision: existing?.baseServerRevision ?? observedRevision,
      syncState: DocumentSyncState.locallyModified,
    );
    _nextLocalOrigin = DocumentChangeOrigin.user;
    await _localStore.saveDraftAndEnqueue(
      local,
      operation: PendingOperation(
        operationId: _idGenerator.nextId(),
        accountKey: _localStore.accountKey,
        documentKey: key,
        type: PendingOperationType.update,
        payload: <String, Object?>{
          'document_id': documentId,
          'updated_at': editTime.toUtc().toIso8601String(),
        },
        baseRevision: existing?.baseServerRevision,
        createdAt: editTime,
      ),
    );
    _uploader.schedule();
  }

  @override
  Future<void> setPinned(bool pinned) async {
    final document = _state.document;
    if (document == null) {
      throw StateError('Document $documentId is not ready');
    }
    await saveDraft(document.copyWith(pinned: pinned));
  }

  DocumentUploadState _uploadState(DocumentSyncState state) {
    return switch (state) {
      DocumentSyncState.synced => DocumentUploadState.clean,
      DocumentSyncState.locallyModified ||
      DocumentSyncState.queued => DocumentUploadState.pending,
      DocumentSyncState.syncing => DocumentUploadState.uploading,
      DocumentSyncState.retryWaiting ||
      DocumentSyncState.conflict => DocumentUploadState.retryWaiting,
    };
  }

  void _emit(DocumentSessionState next) {
    _state = next;
    if (!_closed) _states.add(next);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _localSubscription?.cancel();
    await _states.close();
    _onClosed?.call();
  }
}
