import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_notes/application/native/background_uploader.dart';
import 'package:nx_notes/composition/offline_providers.dart';

class OfflineSyncStatusLabel extends ConsumerWidget {
  const OfflineSyncStatusLabel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploader = ref.watch(backgroundUploaderProvider);
    if (uploader == null) return const SizedBox.shrink();
    return StreamBuilder<BackgroundUploadState>(
      stream: uploader.states,
      initialData: uploader.state,
      builder: (context, snapshot) {
        final status = snapshot.data ?? uploader.state;
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

String _statusText(BackgroundUploadState status) {
  return switch (status.activity) {
    BackgroundUploadActivity.idle =>
      status.lastUploadedAt == null ? 'Saved locally' : 'Synced just now',
    BackgroundUploadActivity.uploading => 'Syncing',
    BackgroundUploadActivity.retryWaiting =>
      'Sync failed - ${status.pendingCount} changes waiting',
  };
}
