import 'dart:async';
import 'dart:math';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_docs/account/account_providers.dart';
import 'package:nx_docs/documents/document_data_providers.dart';
import 'package:nx_docs/sync/clock.dart';
import 'package:nx_docs/sync/connectivity_monitor.dart';
import 'package:nx_docs/sync/document_synchronizer.dart';
import 'package:nx_docs/sync/id_generator.dart';
import 'package:nx_docs/sync/native/background_uploader.dart';
import 'package:nx_docs/sync/native/drift_local_notes_store.dart';
import 'package:nx_docs/sync/native/local_notes_store.dart';
import 'package:nx_docs/sync/native/notes_database.dart';
import 'package:nx_docs/sync/plugin_connectivity_monitor.dart';
import 'package:nx_docs/sync/remote/kgql_document_sync_transport.dart';
import 'package:nx_docs/sync/remote/document_remote_api.dart';
import 'package:nx_docs/sync/remote/repository_document_remote_api.dart';
import 'package:nx_docs/sync/remote/unavailable_document_remote_api.dart';
import 'package:nx_offline/nx_offline.dart' as offline;

final offlineEnabledProvider = Provider<bool>((ref) => !kIsWeb);

final offlineClockProvider = Provider<Clock>((ref) => const SystemClock());
final offlineIdGeneratorProvider = Provider<IdGenerator>(
  (ref) => SecureIdGenerator(),
);
final connectivityMonitorProvider = Provider<ConnectivityMonitor>(
  (ref) => PluginConnectivityMonitor(),
);

/// Stable native lifecycle inputs. Keeping these in providers prevents widget
/// rebuilds from manufacturing new callbacks or transformed streams that would
/// look like a fresh startup and accidentally trigger another synchronization.
final notesDatabaseProvider = Provider.family<NotesDatabase, String>((
  ref,
  accountKey,
) {
  final safeName = accountKey.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  final database = NotesDatabase(
    driftDatabase(
      name: 'nx_notes_$safeName',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
      native: const DriftNativeOptions(shareAcrossIsolates: true),
    ),
  );
  ref.onDispose(database.close);
  return database;
});

final localNotesStoreProvider = Provider<LocalNotesStore?>((ref) {
  if (!ref.watch(offlineEnabledProvider)) return null;
  final session = ref.watch(activeOfflineSessionProvider).value;
  if (session == null) return null;
  final database = ref.watch(notesDatabaseProvider(session.accountKey));
  return DriftLocalNotesStore(
    database: database,
    accountKey: session.accountKey,
  );
});

final documentRemoteApiProvider = Provider<DocumentRemoteApi>((ref) {
  final user = ref.watch(authProvider).value;
  if (user == null) return const UnavailableDocumentRemoteApi();
  return RepositoryDocumentRemoteApi(
    repository: ref.watch(documentRepositoryProvider),
    syncTransport: KgqlDocumentSyncTransport(ref.watch(graphqlClientProvider)),
  );
});

final backgroundUploaderProvider = Provider<BackgroundUploader?>((ref) {
  if (!ref.watch(offlineEnabledProvider)) return null;
  final local = ref.watch(localNotesStoreProvider);
  if (local == null) return null;
  final uploader = BackgroundUploader(
    localStore: local,
    remoteApi: ref.watch(documentRemoteApiProvider),
    clock: ref.watch(offlineClockProvider),
    workerId: ref.watch(offlineIdGeneratorProvider).nextId(),
  );
  ref.onDispose(() => unawaited(uploader.close()));
  return uploader;
});

final documentSynchronizerProvider = Provider<DocumentSynchronizer?>((ref) {
  if (!ref.watch(offlineEnabledProvider)) return null;
  final local = ref.watch(localNotesStoreProvider);
  final uploader = ref.watch(backgroundUploaderProvider);
  if (local == null || uploader == null) return null;
  return DocumentSynchronizer(
    localStore: local,
    remoteApi: ref.watch(documentRemoteApiProvider),
    uploader: uploader,
  );
});

final documentSyncStatusProvider = StreamProvider<offline.SyncStatus>((ref) {
  final source = ref.watch(documentSynchronizerProvider)?.status;
  if (source == null) {
    return Stream<offline.SyncStatus>.value(const offline.SyncStatus.idle());
  }
  return (() async* {
    yield source.status;
    yield* source.statusChanges;
  })();
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
