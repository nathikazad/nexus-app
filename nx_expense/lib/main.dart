import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/app_sync.dart';

import 'package:nx_expense/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  StartupTiming.begin();
  runApp(
    ProviderScope(
      overrides: [
        syncTelemetryProvider.overrideWithValue((event, _) {
          StartupTiming.mark('sync_$event');
        }),
        retainAuthSessionWhenOfflineProvider.overrideWithValue(!kIsWeb),
        dbAuditSourceKindProvider.overrideWithValue('nx_expense'),
        nexusClientAppIdProvider.overrideWithValue(
          kIsWeb ? 'nx_expense_web' : 'nx_expense',
        ),
      ],
      child: const NexusExpenseApp(),
    ),
  );
}
