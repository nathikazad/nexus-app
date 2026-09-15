/// Authenticated composition root used by every app.
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_data/nx_data.dart';
import 'app_reads.dart';
import 'app_sync.dart';
import 'nx_db.dart';
export 'package:nx_data/nx_data.dart'
    show AppDataDefinition, AppDataSession, AppDataHost;

AppDataSession? createAppSession(
  Ref ref, {
  required AppDataDefinition definition,
  OfflineSyncBackend? offline,
  Stream<bool>? onlineChanges,
}) {
  if (ref.watch(authProvider).value == null) return null;
  final client = AppSyncClient(
    ref.watch(graphqlClientProvider),
    definition.name,
  );
  final reads = ref.watch(appReadsProvider(definition.name));
  final session = AppDataSession(
    definition: definition,
    offline: offline,
    onlineChanges: onlineChanges,
    remoteChanges: ref.watch(appSyncChangesProvider(definition.name)),
    checkFreshness: (refresh) =>
        client.refreshIfChanged(refresh, invalidate: reads?.invalidateChanges),
  );
  ref.onDispose(() => unawaited(session.close()));
  return session;
}
