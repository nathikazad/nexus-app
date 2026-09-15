import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/sync/sync_providers.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:nx_db/app_sync.dart' as sync;

final class CardSyncLifecycle extends ConsumerWidget {
  const CardSyncLifecycle({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppSyncLifecycle(
      synchronize: ref.watch(cardsLifecycleSyncProvider),
      onlineChanges: ref.watch(cardsConnectivityChangesProvider),
      remoteChanges: ref.watch(sync.appSyncChangesProvider('cards')),
      checkInterval: sync.appStateSyncEnabled
          ? const Duration(seconds: 30)
          : null,
      child: child,
    );
  }
}
