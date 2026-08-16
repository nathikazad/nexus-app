import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/app/recall_app.dart';
import 'package:nx_cards/sync/lifecycle.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_live_agent/nx_live_agent.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initializeLiveAgentPlatform();
  runApp(
    ProviderScope(
      overrides: [
        dbAuditSourceKindProvider.overrideWithValue('nx_cards'),
        nexusClientAppIdProvider.overrideWithValue('nx_cards'),
        retainAuthSessionWhenOfflineProvider.overrideWithValue(!kIsWeb),
      ],
      child: const CardSyncLifecycle(child: NexusCardsApp()),
    ),
  );
}
