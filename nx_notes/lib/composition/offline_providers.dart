import 'dart:math';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_notes/application/offline_notes_service.dart';
import 'package:nx_notes/application/ports/clock.dart';
import 'package:nx_notes/application/ports/connectivity_monitor.dart';
import 'package:nx_notes/application/ports/id_generator.dart';
import 'package:nx_notes/application/ports/local_notes_store.dart';
import 'package:nx_notes/application/ports/remote_document_gateway.dart';
import 'package:nx_notes/application/sync/document_sync_engine.dart';
import 'package:nx_notes/application/ports/session_store.dart';
import 'package:nx_notes/application/session/offline_session_restorer.dart';
import 'package:nx_notes/data/connectivity/plugin_connectivity_monitor.dart';
import 'package:nx_notes/data/local/drift/drift_local_notes_store.dart';
import 'package:nx_notes/data/local/drift/notes_database.dart';
import 'package:nx_notes/data/providers.dart';
import 'package:nx_notes/data/remote/kgql/kgql_remote_document_gateway.dart';
import 'package:nx_notes/data/remote/unavailable/unavailable_remote_document_gateway.dart';
import 'package:nx_notes/data/session/http_session_probe.dart';
import 'package:nx_notes/data/session/preferences_session_store.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/sync/document_revision.dart';
import 'package:nx_notes/domain/sync/remote_document.dart';
import 'package:shared_preferences/shared_preferences.dart';

final activeOfflineSessionProvider = FutureProvider<CachedSession?>((
  ref,
) async {
  final preferences = await SharedPreferences.getInstance();
  final store = PreferencesSessionStore(preferences);
  final auth = ref.watch(authProvider);
  final user = auth.value;
  if (user != null) {
    final session = CachedSession(
      userId: user.userId,
      backendPreset: user.preset.key,
    );
    await store.save(session);
    return session;
  }
  final cached = await store.load();
  if (cached == null) return null;
  final probe = HttpSessionProbe();
  ref.onDispose(probe.close);
  final result = await OfflineSessionRestorer(
    store: store,
    probe: probe.call,
  ).restore();
  return result.session;
});

final offlineClockProvider = Provider<Clock>((ref) => const SystemClock());

final offlineIdGeneratorProvider = Provider<IdGenerator>(
  (ref) => SecureIdGenerator(),
);

final connectivityMonitorProvider = Provider<ConnectivityMonitor>(
  (ref) => PluginConnectivityMonitor(),
);

final localNotesStoreProvider = Provider<LocalNotesStore?>((ref) {
  final session = ref.watch(activeOfflineSessionProvider).value;
  if (session == null) return null;
  final accountKey = session.accountKey;
  final safeName = accountKey.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  final database = NotesDatabase(driftDatabase(name: 'nx_notes_$safeName'));
  ref.onDispose(database.close);
  return DriftLocalNotesStore(database: database, accountKey: accountKey);
});

final remoteDocumentGatewayProvider = Provider<RemoteDocumentGateway?>((ref) {
  final session = ref.watch(activeOfflineSessionProvider).value;
  if (session == null) return null;
  final user = ref.watch(authProvider).value;
  if (user == null) return const UnavailableRemoteDocumentGateway();
  return KgqlRemoteDocumentGateway(
    repository: ref.watch(documentRepositoryProvider),
  );
});

final documentSyncEngineProvider = Provider<DocumentSyncEngine?>((ref) {
  final local = ref.watch(localNotesStoreProvider);
  final remote = ref.watch(remoteDocumentGatewayProvider);
  if (local == null || remote == null) return null;
  final engine = DocumentSyncEngine(
    localStore: local,
    remoteGateway: remote,
    clock: ref.watch(offlineClockProvider),
    idGenerator: ref.watch(offlineIdGeneratorProvider),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

final offlineNotesServiceProvider = Provider<OfflineNotesService?>((ref) {
  final local = ref.watch(localNotesStoreProvider);
  final engine = ref.watch(documentSyncEngineProvider);
  if (local == null || engine == null) return null;
  return OfflineNotesService(
    localStore: local,
    syncEngine: engine,
    clock: ref.watch(offlineClockProvider),
    idGenerator: ref.watch(offlineIdGeneratorProvider),
  );
});

/// Local-first document read used by editor-facing code during migration.
final offlineDocumentProvider = FutureProvider.family<NxDocument?, int>((
  ref,
  remoteId,
) async {
  final service = ref.watch(offlineNotesServiceProvider);
  if (service == null) {
    return ref.watch(documentRepositoryProvider).getById(remoteId);
  }
  final key = DocumentKey(localId: 'remote-$remoteId', remoteId: remoteId);
  final local = await service.getDocument(key);
  if (local != null) return local.document;

  final remote = await ref.watch(documentRepositoryProvider).getById(remoteId);
  if (remote == null) return null;
  await service.importRemoteDocuments(<RemoteDocument>[
    RemoteDocument(
      key: key,
      document: remote,
      revision: RemoteRevision(remote.updatedAt.toUtc().toIso8601String()),
    ),
  ]);
  return remote;
});

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

class SecureIdGenerator implements IdGenerator {
  SecureIdGenerator({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  @override
  String nextId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final random = List<int>.generate(
      16,
      (_) => _random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '$timestamp-$random';
  }
}
