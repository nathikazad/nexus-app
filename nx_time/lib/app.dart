import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_theme.dart';
import 'router.dart';

/// Root widget: [MaterialApp.router] + [routerProvider], like nx_expense’s shell entry.
class NexusTimeApp extends ConsumerWidget {
  const NexusTimeApp({super.key, this.initialTabIndex = 0});

  /// Initial bottom-nav index (0–3). Used by screenshot driver tests (`?tab=`).
  final int initialTabIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider(initialTabIndex));
    return MaterialApp.router(
      title: 'Nexus Time',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}
