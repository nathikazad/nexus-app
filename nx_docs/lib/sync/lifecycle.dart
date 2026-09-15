import 'package:nx_db/app_session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_docs/sync/sync_providers.dart';
import 'package:nx_docs/workspace/workspace_providers.dart';
import 'package:nx_offline/nx_offline.dart' as offline;
import 'package:nx_db/auth.dart';

class OfflineSyncLifecycle extends ConsumerWidget {
  const OfflineSyncLifecycle({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppDataHost(
      session: ref.watch(docsDataSessionProvider),
      child: child,
    );
  }
}

final docsDataSessionProvider = Provider<AppDataSession?>((ref) {
  if (ref.watch(authProvider).value == null) return null;
  final workspace = ref.watch(documentWorkspaceProvider);
  if (workspace == null) return null;
  return createAppSession(ref,
    definition: AppDataDefinition(name: 'docs', refreshVisible: workspace.refreshVisible),
    offline: ref.watch(offlineEnabledProvider)
        ? offline.PersistentSyncBackend((reason) => workspace.syncLibrary(reason: reason)) : null,
    onlineChanges: ref.watch(offlineConnectivityChangesProvider),
  );
});

final offlineConnectivityChangesProvider = Provider<Stream<bool>?>((ref) {
  if (!ref.watch(offlineEnabledProvider)) return null;
  return ref.watch(connectivityMonitorProvider).onlineChanges;
});
