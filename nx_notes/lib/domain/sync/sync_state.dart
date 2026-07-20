enum DocumentSyncState {
  synced,
  locallyModified,
  queued,
  syncing,
  retryWaiting,
  conflict,
}

extension DocumentSyncStateTransitions on DocumentSyncState {
  bool canTransitionTo(DocumentSyncState next) {
    if (next == this) return true;
    return switch (this) {
      DocumentSyncState.synced =>
        next == DocumentSyncState.locallyModified ||
            next == DocumentSyncState.queued,
      DocumentSyncState.locallyModified =>
        next == DocumentSyncState.queued || next == DocumentSyncState.conflict,
      DocumentSyncState.queued =>
        next == DocumentSyncState.syncing ||
            next == DocumentSyncState.locallyModified ||
            next == DocumentSyncState.conflict,
      DocumentSyncState.syncing =>
        next == DocumentSyncState.synced ||
            next == DocumentSyncState.retryWaiting ||
            next == DocumentSyncState.conflict ||
            next == DocumentSyncState.locallyModified,
      DocumentSyncState.retryWaiting =>
        next == DocumentSyncState.syncing ||
            next == DocumentSyncState.locallyModified ||
            next == DocumentSyncState.conflict,
      DocumentSyncState.conflict =>
        next == DocumentSyncState.locallyModified ||
            next == DocumentSyncState.synced,
    };
  }
}
