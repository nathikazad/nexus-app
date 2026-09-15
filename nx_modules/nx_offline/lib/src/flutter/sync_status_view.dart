import 'package:flutter/material.dart';
import '../core/sync_models.dart';
import '../sync/sync_ports.dart';
final class SyncStatusView extends StatelessWidget {
  const SyncStatusView({required this.source, this.textStyle, super.key});

  final SyncStatusSource source;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncStatus>(
      stream: source.statusChanges,
      initialData: source.status,
      builder: (context, snapshot) {
        final status = snapshot.data ?? source.status;
        return Semantics(
          label: 'Synchronization status',
          child: Text(_label(status), style: textStyle),
        );
      },
    );
  }

  String _label(SyncStatus status) {
    return switch (status.activity) {
      SyncActivity.idle =>
        status.lastSyncedAt == null ? 'Saved locally' : 'Synced',
      SyncActivity.syncing => 'Syncing',
      SyncActivity.retryWaiting =>
        'Sync pending - ${status.pendingCount} changes',
      SyncActivity.blocked => 'Sync requires attention',
    };
  }
}
