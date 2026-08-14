import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_docs/sync/sync_providers.dart';
import 'package:nx_docs/workspace/workspace_providers.dart';
import 'package:nx_offline/nx_offline.dart' as offline;

class OfflineSyncLifecycle extends ConsumerWidget {
  const OfflineSyncLifecycle({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return offline.OfflineLifecycle(
      synchronize: ref.watch(offlineLifecycleSyncProvider),
      onlineChanges: ref.watch(offlineConnectivityChangesProvider),
      child: child,
    );
  }
}

final offlineLifecycleSyncProvider = Provider<offline.OfflineSynchronize?>((
  ref,
) {
  if (!ref.watch(offlineEnabledProvider)) return null;
  final workspace = ref.watch(documentWorkspaceProvider);
  if (workspace == null) return null;
  return (reason) => workspace.syncLibrary(reason: reason);
});

final offlineConnectivityChangesProvider = Provider<Stream<bool>?>((ref) {
  if (!ref.watch(offlineEnabledProvider)) return null;
  return ref.watch(connectivityMonitorProvider).onlineChanges;
});
