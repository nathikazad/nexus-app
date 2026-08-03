import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_notes/composition/offline_providers.dart';
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
