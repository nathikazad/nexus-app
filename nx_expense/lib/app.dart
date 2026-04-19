import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_expense/core/theme/app_theme.dart';
import 'package:nx_expense/router.dart';

class NexusExpenseApp extends ConsumerWidget {
  const NexusExpenseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'EXPNS.',
      theme: buildExpenseTheme(),
      routerConfig: router,
    );
  }
}
