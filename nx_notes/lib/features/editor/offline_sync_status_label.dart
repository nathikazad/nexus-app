import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_notes/composition/offline_providers.dart';
import 'package:nx_notes/domain/sync/sync_status.dart';

class OfflineSyncStatusLabel extends ConsumerWidget {
  const OfflineSyncStatusLabel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(offlineNotesServiceProvider);
    if (service == null) return const SizedBox.shrink();
    return StreamBuilder<SyncStatus>(
      stream: service.syncStatusChanges,
      initialData: service.syncStatus,
      builder: (context, snapshot) {
        final status = snapshot.data ?? service.syncStatus;
        return Semantics(
          label: 'Document synchronization status',
          child: Text(
            _statusText(status),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        );
      },
    );
  }
}

String _statusText(SyncStatus status) {
  return switch (status.activity) {
    SyncActivity.idle =>
      status.lastSyncedAt == null ? 'Saved locally' : 'Synced just now',
    SyncActivity.offline => 'Offline - ${status.pendingCount} changes waiting',
    SyncActivity.syncing => 'Syncing',
    SyncActivity.retryWaiting =>
      'Sync failed - ${status.pendingCount} changes waiting',
    SyncActivity.blocked => 'Conflict or sign-in requires attention',
  };
}
