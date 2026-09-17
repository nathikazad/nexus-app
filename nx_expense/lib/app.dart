import 'package:nx_db/app_session.dart';
import 'data/sync/expense_sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:nx_db/auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_expense/core/theme/app_theme.dart';
import 'package:nx_expense/router.dart';

class NexusExpenseApp extends ConsumerWidget {
  const NexusExpenseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return AppDataHost(
      session: ref.watch(expenseDataSessionProvider),
      child: MaterialApp.router(
        title: 'EXPNS.',
        theme: buildExpenseTheme(),
        routerConfig: router,
        builder: (context, child) => DomainSessionGate(child: child!),
      ),
    );
  }
}
