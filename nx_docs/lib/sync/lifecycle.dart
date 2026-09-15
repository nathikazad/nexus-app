import 'package:nx_db/app_reads.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_docs/sync/sync_providers.dart';
import 'package:nx_docs/workspace/workspace_providers.dart';
import 'package:nx_offline/nx_offline.dart' as offline;
import 'package:nx_db/app_sync.dart' as sync;
import 'package:nx_db/riverpod.dart';
import 'package:nx_db/auth.dart';

class OfflineSyncLifecycle extends ConsumerWidget {
  const OfflineSyncLifecycle({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return offline.AppSyncLifecycle(
      synchronize: ref.watch(offlineLifecycleSyncProvider),
      onlineChanges: ref.watch(offlineConnectivityChangesProvider),
      remoteChanges: ref.watch(sync.appSyncChangesProvider('docs')),
      checkInterval: sync.appStateSyncEnabled
          ? const Duration(seconds: 30)
          : null,
      child: child,
    );
  }
}

final offlineLifecycleSyncProvider = Provider<offline.AppSynchronize?>((ref) {
  if (ref.watch(authProvider).value == null) return null;
  final workspace = ref.watch(documentWorkspaceProvider);
  if (workspace == null) return null;
  if (!ref.watch(offlineEnabledProvider)) {
    if (!sync.appStateSyncEnabled) return null;
    final client = sync.AppSyncClient(ref.watch(graphqlClientProvider), 'docs');
    return (reason) => client.refreshIfChanged(() {
      return workspace.syncLibrary(reason: reason);
    }, invalidate: ref.read(appReadsProvider('docs'))?.invalidateChanges);
  }
  return (reason) => workspace.syncLibrary(reason: reason);
});

final offlineConnectivityChangesProvider = Provider<Stream<bool>?>((ref) {
  if (!ref.watch(offlineEnabledProvider)) return null;
  return ref.watch(connectivityMonitorProvider).onlineChanges;
});
