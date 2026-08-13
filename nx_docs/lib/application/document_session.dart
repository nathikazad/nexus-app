import 'package:nx_docs/domain/document/document.dart';

enum DocumentPhase { opening, ready, unavailableOffline, notFound }

enum DocumentUploadState { clean, pending, uploading, retryWaiting }

enum DocumentChangeOrigin {
  localCache,
  user,
  initialRemoteLoad,
  remoteRefresh,
  snapshotRestore,
}

final class DocumentSessionState {
  const DocumentSessionState({
    this.phase = DocumentPhase.opening,
    this.document,
    this.isRefreshing = false,
    this.uploadState = DocumentUploadState.clean,
    this.origin = DocumentChangeOrigin.localCache,
    this.error,
  });

  final DocumentPhase phase;
  final NxDocument? document;
  final bool isRefreshing;
  final DocumentUploadState uploadState;
  final DocumentChangeOrigin origin;
  final Object? error;

  DocumentSessionState copyWith({
    DocumentPhase? phase,
    NxDocument? document,
    bool? isRefreshing,
    DocumentUploadState? uploadState,
    DocumentChangeOrigin? origin,
    Object? error,
    bool clearError = false,
  }) {
    return DocumentSessionState(
      phase: phase ?? this.phase,
      document: document ?? this.document,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      uploadState: uploadState ?? this.uploadState,
      origin: origin ?? this.origin,
      error: clearError ? null : error ?? this.error,
    );
  }
}

abstract interface class DocumentSession {
  int get documentId;

  DocumentSessionState get state;

  Stream<DocumentSessionState> get states;

  Future<void> saveDraft(NxDocument document);

  Future<void> setPinned(bool pinned);

  Future<void> refresh();

  Future<void> close();
}
