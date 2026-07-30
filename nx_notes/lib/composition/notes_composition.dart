import 'dart:async';
import 'dart:math';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_notes/application/document_session.dart';
import 'package:nx_notes/application/history/document_history_service.dart';
import 'package:nx_notes/application/links/document_link_service.dart';
import 'package:nx_notes/application/native/background_uploader.dart';
import 'package:nx_notes/application/native/native_notes_workspace.dart';
import 'package:nx_notes/application/notes_workspace.dart';
import 'package:nx_notes/application/ports/clock.dart';
import 'package:nx_notes/application/ports/connectivity_monitor.dart';
import 'package:nx_notes/application/ports/id_generator.dart';
import 'package:nx_notes/application/ports/last_opened_document_store.dart';
import 'package:nx_notes/application/ports/local_notes_store.dart';
import 'package:nx_notes/application/ports/notes_remote_api.dart';
import 'package:nx_notes/application/ports/session_store.dart';
import 'package:nx_notes/application/session/notes_logout_service.dart';
import 'package:nx_notes/application/session/offline_session_restorer.dart';
import 'package:nx_notes/application/publishing/document_publish_service.dart';
import 'package:nx_notes/application/web/web_notes_workspace.dart';
import 'package:nx_notes/data/connectivity/plugin_connectivity_monitor.dart';
import 'package:nx_notes/data/local/drift/drift_local_notes_store.dart';
import 'package:nx_notes/data/local/drift/notes_database.dart';
import 'package:nx_notes/data/providers.dart';
import 'package:nx_notes/data/remote/repository_notes_remote_api.dart';
import 'package:nx_notes/data/remote/unavailable/unavailable_notes_remote_api.dart';
import 'package:nx_notes/data/session/http_session_probe.dart';
import 'package:nx_notes/data/session/preferences_last_opened_document_store.dart';
import 'package:nx_notes/data/session/preferences_session_store.dart';
import 'package:nx_notes/domain/catalog/catalog_query.dart';
import 'package:nx_notes/domain/catalog/catalog_state.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/tags/tag_system.dart';
import 'package:nx_notes/domain/tags/tag_system_index.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Native builds use SQLite and an outbox. Web builds use direct KGQL only.
final offlineEnabledProvider = Provider<bool>((ref) => !kIsWeb);

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
  if (!ref.watch(offlineEnabledProvider)) return null;
  final session = ref.watch(activeOfflineSessionProvider).value;
  if (session == null) return null;
  final database = ref.watch(notesDatabaseProvider(session.accountKey));
  return DriftLocalNotesStore(
    database: database,
    accountKey: session.accountKey,
  );
});

final notesRemoteApiProvider = Provider<NotesRemoteApi>((ref) {
  final user = ref.watch(authProvider).value;
  if (user == null) return const UnavailableNotesRemoteApi();
  return RepositoryNotesRemoteApi(ref.watch(documentRepositoryProvider));
});

final backgroundUploaderProvider = Provider<BackgroundUploader?>((ref) {
  if (!ref.watch(offlineEnabledProvider)) return null;
  final local = ref.watch(localNotesStoreProvider);
  if (local == null) return null;
  final uploader = BackgroundUploader(
    localStore: local,
    remoteApi: ref.watch(notesRemoteApiProvider),
    clock: ref.watch(offlineClockProvider),
    workerId: ref.watch(offlineIdGeneratorProvider).nextId(),
  );
  ref.onDispose(() => unawaited(uploader.close()));
  return uploader;
});

final notesWorkspaceProvider = Provider<NotesWorkspace?>((ref) {
  final remote = ref.watch(notesRemoteApiProvider);
  final NotesWorkspace? workspace;
  if (ref.watch(offlineEnabledProvider)) {
    final local = ref.watch(localNotesStoreProvider);
    final uploader = ref.watch(backgroundUploaderProvider);
    if (local == null || uploader == null) return null;
    workspace = NativeNotesWorkspace(
      localStore: local,
      remoteApi: remote,
      uploader: uploader,
      clock: ref.watch(offlineClockProvider),
      idGenerator: ref.watch(offlineIdGeneratorProvider),
    );
  } else {
    workspace = WebNotesWorkspace(remoteApi: remote);
  }
  ref.onDispose(() => unawaited(workspace!.close()));
  return workspace;
});

final documentHistoryServiceProvider = Provider<DocumentHistoryService?>((ref) {
  final workspace = ref.watch(notesWorkspaceProvider);
  if (workspace == null) return null;
  return DocumentHistoryService(
    repository: ref.watch(documentRepositoryProvider),
    workspace: workspace,
  );
});

final documentLinkServiceProvider = Provider<DocumentLinkService?>((ref) {
  final workspace = ref.watch(notesWorkspaceProvider);
  if (workspace == null) return null;
  return DocumentLinkService(
    repository: ref.watch(documentRepositoryProvider),
    workspace: workspace,
  );
});

final documentPublishServiceProvider = Provider<DocumentPublishService?>((ref) {
  final workspace = ref.watch(notesWorkspaceProvider);
  if (workspace == null) return null;
  return DocumentPublishService(
    workspace: workspace,
    clock: ref.watch(offlineClockProvider),
    trigger: ref.watch(mirrorPublishTriggerProvider),
  );
});

final catalogStateProvider = StreamProvider.autoDispose
    .family<CatalogState, CatalogQuery>((ref, query) {
      final workspace = ref.watch(notesWorkspaceProvider);
      if (workspace == null) {
        return Stream<CatalogState>.value(const CatalogState());
      }
      return workspace.watchCatalog(query);
    });

final documentSessionProvider = Provider.autoDispose
    .family<DocumentSession?, int>((ref, documentId) {
      final workspace = ref.watch(notesWorkspaceProvider);
      if (workspace == null) return null;
      final session = workspace.openDocument(documentId);
      ref.onDispose(() => unawaited(session.close()));
      return session;
    });

final documentSessionStateProvider = StreamProvider.autoDispose
    .family<DocumentSessionState, int>((ref, documentId) async* {
      final session = ref.watch(documentSessionProvider(documentId));
      if (session == null) {
        yield const DocumentSessionState();
        return;
      }
      yield* _sessionStates(session);
    });

typedef NotesLibraryRefresh = Future<void> Function();

final notesLibraryRefreshProvider = Provider<NotesLibraryRefresh>((ref) {
  return () async {
    final workspace = ref.read(notesWorkspaceProvider);
    if (workspace == null) throw StateError('Notes are not ready yet.');
    await workspace.uploadPending();
    await Future.wait(<Future<void>>[
      workspace.refreshCatalog(const CatalogQuery.recent()),
      workspace.refreshCatalog(const CatalogQuery.pinned()),
      workspace.refreshCatalog(const CatalogQuery.books()),
      workspace.refreshCatalog(const CatalogQuery.all()),
    ]);
  };
});

final offlineAllDocumentsProvider = StreamProvider<List<NxDocument>>((ref) {
  return _watchDocuments(ref, const CatalogQuery.all());
});

final offlineRecentDocumentsProvider = StreamProvider<List<NxDocument>>((ref) {
  return _watchDocuments(ref, const CatalogQuery.recent());
});

final offlinePinnedDocumentsProvider = StreamProvider<List<NxDocument>>((ref) {
  return _watchDocuments(ref, const CatalogQuery.pinned());
});

final offlineBooksProvider = StreamProvider<List<NxDocument>>((ref) {
  return _watchDocuments(ref, const CatalogQuery.books());
});

final offlineDocumentSearchProvider =
    StreamProvider.family<List<NxDocument>, String>((ref, searchText) {
      if (searchText.trim().isEmpty) {
        return Stream<List<NxDocument>>.value(const <NxDocument>[]);
      }
      return _watchDocuments(ref, CatalogQuery.search(searchText));
    });

final offlineTagSystemsProvider = StreamProvider<List<TagSystem>>((ref) {
  return _watchDocuments(
    ref,
    const CatalogQuery.all(),
  ).map(tagSystemsFromDocuments);
});

Stream<List<NxDocument>> _watchDocuments(Ref ref, CatalogQuery query) {
  final workspace = ref.watch(notesWorkspaceProvider);
  if (workspace == null) {
    return Stream<List<NxDocument>>.value(const <NxDocument>[]);
  }
  return workspace
      .watchCatalog(query)
      .map(
        (state) => state.items
            .map((summary) => summary.toDocument())
            .toList(growable: false),
      );
}

final offlineDocumentProvider = StreamProvider.family<NxDocument?, int>((
  ref,
  documentId,
) async* {
  final session = ref.watch(documentSessionProvider(documentId));
  if (session == null) {
    yield null;
    return;
  }
  await for (final state in _sessionStates(session)) {
    yield state.document;
  }
});

Stream<DocumentSessionState> _sessionStates(DocumentSession session) {
  late StreamSubscription<DocumentSessionState> subscription;
  return Stream<DocumentSessionState>.multi((controller) {
    subscription = session.states.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.add(session.state);
    controller.onCancel = subscription.cancel;
  });
}

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
