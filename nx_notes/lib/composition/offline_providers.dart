import 'dart:math';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_notes/application/offline_notes_service.dart';
import 'package:nx_notes/application/ports/clock.dart';
import 'package:nx_notes/application/ports/connectivity_monitor.dart';
import 'package:nx_notes/application/ports/id_generator.dart';
import 'package:nx_notes/application/ports/last_opened_document_store.dart';
import 'package:nx_notes/application/ports/local_notes_store.dart';
import 'package:nx_notes/application/ports/remote_document_gateway.dart';
import 'package:nx_notes/application/sync/notes_sync_engine.dart';
import 'package:nx_notes/application/ports/session_store.dart';
import 'package:nx_notes/application/session/offline_session_restorer.dart';
import 'package:nx_notes/application/session/notes_logout_service.dart';
import 'package:nx_notes/data/connectivity/plugin_connectivity_monitor.dart';
import 'package:nx_notes/data/local/drift/drift_local_notes_store.dart';
import 'package:nx_notes/data/local/drift/notes_database.dart';
import 'package:nx_notes/data/providers.dart';
import 'package:nx_notes/data/remote/kgql/kgql_remote_document_gateway.dart';
import 'package:nx_notes/data/remote/unavailable/unavailable_remote_document_gateway.dart';
import 'package:nx_notes/data/session/http_session_probe.dart';
import 'package:nx_notes/data/session/preferences_last_opened_document_store.dart';
import 'package:nx_notes/data/session/preferences_session_store.dart';
import 'package:nx_notes/data/sync/nx_offline_notes_sync_engine.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/document/document_query.dart';
import 'package:nx_notes/domain/sync/document_revision.dart';
import 'package:nx_notes/domain/sync/remote_document.dart';
import 'package:nx_notes/domain/tags/tag_system.dart';
import 'package:nx_notes/domain/tags/tag_system_index.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nx_offline/nx_offline.dart' as offline;

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

typedef NotesLogoutAction = Future<void> Function();

final notesLogoutProvider = Provider<NotesLogoutAction>((ref) {
  return () async {
    final preferences = await SharedPreferences.getInstance();
    await NotesLogoutService(
      sessionStore: PreferencesSessionStore(preferences),
      logoutAuthentication: ref.read(authProvider.notifier).logout,
      invalidateOfflineSession: () {
        ref.invalidate(activeOfflineSessionProvider);
      },
    ).logout();
  };
});

final lastOpenedDocumentStoreProvider = FutureProvider<LastOpenedDocumentStore>(
  (ref) async {
    final preferences = await SharedPreferences.getInstance();
    return PreferencesLastOpenedDocumentStore(preferences);
  },
);

final offlineClockProvider = Provider<Clock>((ref) => const SystemClock());

final offlineIdGeneratorProvider = Provider<IdGenerator>(
  (ref) => SecureIdGenerator(),
);

final connectivityMonitorProvider = Provider<ConnectivityMonitor>(
  (ref) => PluginConnectivityMonitor(),
);

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
  final session = ref.watch(activeOfflineSessionProvider).value;
  if (session == null) return null;
  final accountKey = session.accountKey;
  final database = ref.watch(notesDatabaseProvider(accountKey));
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

final documentSyncEngineProvider = Provider<NotesSyncEngine?>((ref) {
  final session = ref.watch(activeOfflineSessionProvider).value;
  final local = ref.watch(localNotesStoreProvider);
  final remote = ref.watch(remoteDocumentGatewayProvider);
  if (session == null || local == null || remote == null) return null;
  final engine = NxOfflineNotesSyncEngine(
    localStore: local,
    remoteGateway: remote,
    account: offline.AccountScope(
      backend: session.backendPreset,
      userId: session.userId,
      application: 'nx_notes',
    ),
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

final offlineAllDocumentsProvider = StreamProvider<List<NxDocument>>((ref) {
  return _watchOfflineDocuments(ref, const DocumentQuery());
});

final offlineRecentDocumentsProvider = StreamProvider<List<NxDocument>>((ref) {
  return _watchOfflineDocuments(
    ref,
    const DocumentQuery(),
  ).map((documents) => documents.take(20).toList(growable: false));
});

final offlinePinnedDocumentsProvider = StreamProvider<List<NxDocument>>((ref) {
  return _watchOfflineDocuments(
    ref,
    const DocumentQuery(pinnedOnly: true),
  ).map((documents) => documents.take(20).toList(growable: false));
});

final offlineBooksProvider = StreamProvider<List<NxDocument>>((ref) {
  return _watchOfflineDocuments(ref, const DocumentQuery()).map(
    (documents) => documents
        .where((document) => document.isBook)
        .take(100)
        .toList(growable: false),
  );
});

final offlineDocumentSearchProvider =
    StreamProvider.family<List<NxDocument>, String>((ref, searchText) {
      if (searchText.trim().isEmpty) {
        return Stream<List<NxDocument>>.value(const <NxDocument>[]);
      }
      return _watchOfflineDocuments(ref, DocumentQuery(searchText: searchText));
    });

final offlineTagSystemsProvider = StreamProvider<List<TagSystem>>((ref) {
  return _watchOfflineDocuments(
    ref,
    const DocumentQuery(),
  ).map(tagSystemsFromDocuments);
});

Stream<List<NxDocument>> _watchOfflineDocuments(Ref ref, DocumentQuery query) {
  final service = ref.watch(offlineNotesServiceProvider);
  if (service == null) {
    return Stream<List<NxDocument>>.value(const <NxDocument>[]);
  }
  return service
      .watchDocuments(query)
      .map(
        (documents) => documents
            .map((local) => local.document)
            .where((document) => document.id > 0)
            .toList(growable: false),
      );
}

/// Live local-first document read used by editor-facing code.
final offlineDocumentProvider = StreamProvider.family<NxDocument?, int>((
  ref,
  remoteId,
) async* {
  final service = ref.watch(offlineNotesServiceProvider);
  if (service == null) {
    yield await ref.watch(documentRepositoryProvider).getById(remoteId);
    return;
  }
  final key = DocumentKey(localId: 'remote-$remoteId', remoteId: remoteId);
  var attemptedRemoteRead = false;
  await for (final local in service.watchDocument(key)) {
    if (local != null) {
      yield local.document;
      continue;
    }
    if (!attemptedRemoteRead) {
      attemptedRemoteRead = true;
      final remote = await ref
          .watch(documentRepositoryProvider)
          .getById(remoteId);
      if (remote != null) {
        await service.importRemoteDocuments(<RemoteDocument>[
          RemoteDocument(
            key: key,
            document: remote,
            revision: RemoteRevision(
              remote.updatedAt.toUtc().toIso8601String(),
            ),
          ),
        ]);
        continue;
      }
    }
    yield null;
  }
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
