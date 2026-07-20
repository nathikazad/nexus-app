enum SyncActivity { idle, offline, syncing, retryWaiting, blocked }

class SyncStatus {
  const SyncStatus({
    required this.activity,
    this.pendingCount = 0,
    this.lastSyncedAt,
    this.message,
  });

  const SyncStatus.idle({DateTime? lastSyncedAt})
    : this(activity: SyncActivity.idle, lastSyncedAt: lastSyncedAt);

  final SyncActivity activity;
  final int pendingCount;
  final DateTime? lastSyncedAt;
  final String? message;
}
