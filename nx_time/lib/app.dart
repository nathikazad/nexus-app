import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme/app_theme.dart';

class NxTimeApp extends ConsumerWidget {
  const NxTimeApp({super.key, this.initialTabIndex = 0});

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
