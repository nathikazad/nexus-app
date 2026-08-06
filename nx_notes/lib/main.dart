import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_notes/app.dart';
import 'package:nx_notes/features/shell/offline_sync_lifecycle.dart';
import 'package:nx_utils/nx_utils.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android)) {
    await NxStoredAudioPlayer.initializeRemoteControls();
  }
  runApp(
    ProviderScope(
      overrides: [dbAuditSourceKindProvider.overrideWithValue('nx_notes')],
      child: const OfflineSyncLifecycle(child: NexusNotesApp()),
    ),
  );
}
