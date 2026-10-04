import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:nx_sync/nx_sync.dart';
import 'package:nx_time/data/domains/domain_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/router.dart';

/// Root widget: [MaterialApp.router] + [routerProvider], like nx_expense’s shell entry.
class NexusTimeApp extends ConsumerWidget {
  const NexusTimeApp({super.key, this.initialTabIndex = 0});

  /// Initial bottom-nav index (0–3). Used by screenshot driver tests (`?tab=`).
  final int initialTabIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider(initialTabIndex));
    final workspace = ref.watch(timeDomainsProvider).asData?.value;
    return AppSyncLifecycle(
      synchronize: workspace == null || workspace.sessions.isEmpty
          ? null
          : workspace.synchronize,
      onlineChanges: timeOnlineChanges,
      checkInterval: const Duration(seconds: 30),
      child: MaterialApp.router(
        title: 'Nexus Time',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        routerConfig: router,
      ),
    );
  }
}

final timeOnlineChanges = Connectivity().onConnectivityChanged.map(
  (states) => !states.contains(ConnectivityResult.none),
);
