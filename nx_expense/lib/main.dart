import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_db/auth.dart';

import 'package:nx_expense/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [
        dbAuditSourceKindProvider.overrideWithValue('nx_expense'),
        nexusClientAppIdProvider.overrideWithValue(
          kIsWeb ? 'nx_expense_web' : 'nx_expense',
        ),
      ],
      child: const NexusExpenseApp(),
    ),
  );
}
