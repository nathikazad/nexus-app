import 'dart:async';

import 'package:nx_notes/application/document_session.dart';
import 'package:nx_notes/application/ports/notes_remote_api.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/sync/remote_save_result.dart';

final class WebDocumentSession implements DocumentSession {
  WebDocumentSession({
    required this.documentId,
    required NotesRemoteApi remoteApi,
    void Function()? onClosed,
  }) : _remoteApi = remoteApi,
       _onClosed = onClosed {
    unawaited(refresh());
  }

  @override
  final int documentId;
  final NotesRemoteApi _remoteApi;
  final void Function()? _onClosed;
  final StreamController<DocumentSessionState> _states =
      StreamController<DocumentSessionState>.broadcast(sync: true);
  DocumentSessionState _state = const DocumentSessionState();
  Future<void>? _activeRefresh;
  bool _closed = false;

  @override
  DocumentSessionState get state => _state;

  @override
  Stream<DocumentSessionState> get states => _states.stream;

  @override
  Future<void> refresh() {
    final active = _activeRefresh;
    if (active != null) return active;
    final run = _refresh();
    _activeRefresh = run;
    return run.whenComplete(() {
      if (identical(_activeRefresh, run)) _activeRefresh = null;
    });
  }

  Future<void> _refresh() async {
    if (_closed) return;
    _emit(_state.copyWith(isRefreshing: true, clearError: true));
    try {
      final document = await _remoteApi.fetchDocument(documentId);
      if (_closed) return;
      _emit(
        _state.copyWith(
          phase: document == null
              ? DocumentPhase.notFound
              : DocumentPhase.ready,
          document: document,
          isRefreshing: false,
          origin: _state.document == null
              ? DocumentChangeOrigin.initialRemoteLoad
              : DocumentChangeOrigin.remoteRefresh,
          clearError: true,
        ),
      );
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
    _emit(
      _state.copyWith(
        phase: DocumentPhase.ready,
        document: document,
        uploadState: DocumentUploadState.uploading,
        origin: DocumentChangeOrigin.user,
        clearError: true,
      ),
    );
    try {
      final result = await _remoteApi.saveDocumentIfNewer(document);
      if (result.status == RemoteSaveStatus.stale) {
        final remote = await _remoteApi.fetchDocument(documentId);
        if (remote != null) {
          _emit(
            _state.copyWith(
              document: remote,
              uploadState: DocumentUploadState.clean,
              origin: DocumentChangeOrigin.remoteRefresh,
            ),
          );
          return;
        }
      }
      _emit(
        _state.copyWith(
          document: document.copyWith(updatedAt: result.updatedAt),
          uploadState: DocumentUploadState.clean,
          origin: DocumentChangeOrigin.user,
        ),
      );
    } catch (error) {
      _emit(
        _state.copyWith(
          uploadState: DocumentUploadState.retryWaiting,
          error: error,
        ),
      );
      rethrow;
    }
  }

  @override
  Future<void> setPinned(bool pinned) async {
    final document = _state.document;
    if (document == null) {
      throw StateError('Document $documentId is not ready');
    }
    await saveDraft(
      document.copyWith(
        pinned: pinned,
        updatedAt: DateTime.now().toUtc(),
        updatedLabel: 'just now',
      ),
    );
  }

  void _emit(DocumentSessionState next) {
    _state = next;
    if (!_closed) _states.add(next);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _states.close();
    _onClosed?.call();
  }
}
