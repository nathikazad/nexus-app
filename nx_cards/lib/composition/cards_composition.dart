import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/application/cards_workspace.dart';
import 'package:nx_cards/application/native/cards_uploader.dart';
import 'package:nx_cards/application/native/native_cards_workspace.dart';
import 'package:nx_cards/application/ports/cards_sync_transport.dart';
import 'package:nx_cards/application/ports/clock.dart';
import 'package:nx_cards/application/ports/local_cards_store.dart';
import 'package:nx_cards/application/study/study_queue_service.dart';
import 'package:nx_cards/application/sync/card_library_synchronizer.dart';
import 'package:nx_cards/application/web/web_cards_workspace.dart';
import 'package:nx_cards/data/audio/http_card_audio_repository.dart';
import 'package:nx_cards/data/audio/cached_card_audio_repository.dart';
import 'package:nx_cards/data/local/drift/cards_database.dart';
import 'package:nx_cards/data/local/drift/drift_local_cards_store.dart';
import 'package:nx_cards/data/remote/kgql/card_schema.dart';
import 'package:nx_cards/data/remote/kgql/kgql_cards_repository.dart';
import 'package:nx_cards/data/remote/kgql/kgql_cards_sync_transport.dart';
import 'package:nx_cards/domain/card/card_audio_repository.dart';
import 'package:nx_cards/domain/card/cards_repository.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/domain/scheduling/card_scheduler.dart';
import 'package:nx_db/nx_db.dart';
import 'package:nx_offline/nx_offline.dart' as offline;
import 'package:shared_preferences/shared_preferences.dart';

/// Native builds use SQLite and an outbox. Web remains direct-network only.
final cardsOfflineEnabledProvider = Provider<bool>((ref) => !kIsWeb);

final activeCardsSessionProvider = FutureProvider<offline.CachedSession?>((
  ref,
) async {
  final auth = ref.watch(authProvider);
  final user = auth.value;
  if (!ref.watch(cardsOfflineEnabledProvider)) {
    if (user == null) return null;
    return offline.CachedSession(
      serverId: 'nexus-primary',
      userId: user.userId,
      application: 'nx_cards',
      route: user.preset.key,
    );
  }

  final preferences = await SharedPreferences.getInstance();
  final store = offline.PreferencesCachedSessionStore(
    preferences: preferences,
    application: 'nx_cards',
    serverId: 'nexus-primary',
  );
  if (user != null) {
    final session = offline.CachedSession(
      serverId: 'nexus-primary',
      userId: user.userId,
      application: 'nx_cards',
      route: user.preset.key,
    );
    await store.save(session);
    return session;
  }

  return store.load();
});

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final cardsOperationIdProvider = Provider<String Function()>((ref) {
  final random = Random.secure();
  return () {
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final entropy = List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '$timestamp-$entropy';
  };
});

final cardsDatabaseProvider = Provider.family<CardsDatabase, String>((
  ref,
  accountKey,
) {
  final safeName = accountKey.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  final database = CardsDatabase(
    driftDatabase(
      name: 'nx_cards_$safeName',
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

final localCardsStoreProvider = Provider<LocalCardsStore?>((ref) {
  if (!ref.watch(cardsOfflineEnabledProvider)) return null;
  final session = ref.watch(activeCardsSessionProvider).value;
  if (session == null) return null;
  return DriftLocalCardsStore(
    database: ref.watch(cardsDatabaseProvider(session.account.key)),
    account: session.account,
  );
});

final remoteCardsRepositoryProvider = Provider<CardsRepository?>((ref) {
  if (ref.watch(authProvider).value == null) return null;
  return KgqlCardsRepository(ref.watch(graphqlClientProvider));
});

final cardsSyncTransportProvider = Provider<CardsSyncTransport?>((ref) {
  if (ref.watch(authProvider).value == null) return null;
  return KgqlCardsSyncTransport(ref.watch(graphqlClientProvider));
});

final cardsUploaderProvider = Provider<CardsUploader?>((ref) {
  if (!ref.watch(cardsOfflineEnabledProvider)) return null;
  final local = ref.watch(localCardsStoreProvider);
  final transport = ref.watch(cardsSyncTransportProvider);
  if (local == null || transport == null) return null;
  final uploader = CardsUploader(
    localStore: local,
    transport: transport,
    clock: ref.watch(clockProvider),
    workerId: ref.watch(cardsOperationIdProvider)(),
  );
  ref.onDispose(() => unawaited(uploader.close()));
  return uploader;
});

final cardLibrarySynchronizerProvider = Provider<CardLibrarySynchronizer?>((
  ref,
) {
  if (!ref.watch(cardsOfflineEnabledProvider)) return null;
  final local = ref.watch(localCardsStoreProvider);
  if (local == null) return null;
  return CardLibrarySynchronizer(
    localStore: local,
    transport: ref.watch(cardsSyncTransportProvider),
    uploader: ref.watch(cardsUploaderProvider),
    audioRepository: ref.watch(cardAudioRepositoryProvider),
  );
});

final cardsWorkspaceProvider = Provider<CardsWorkspace?>((ref) {
  final CardsWorkspace? workspace;
  if (ref.watch(cardsOfflineEnabledProvider)) {
    final local = ref.watch(localCardsStoreProvider);
    final synchronizer = ref.watch(cardLibrarySynchronizerProvider);
    if (local == null || synchronizer == null) return null;
    workspace = NativeCardsWorkspace(
      localStore: local,
      remoteRepository: ref.watch(remoteCardsRepositoryProvider),
      transport: ref.watch(cardsSyncTransportProvider),
      uploader: ref.watch(cardsUploaderProvider),
      synchronizer: synchronizer,
      clock: ref.watch(clockProvider),
      newOperationId: ref.watch(cardsOperationIdProvider),
    );
  } else {
    final remote = ref.watch(remoteCardsRepositoryProvider);
    if (remote == null) return null;
    workspace = WebCardsWorkspace(remote);
  }
  ref.onDispose(() => unawaited(workspace!.close()));
  return workspace;
});

final cardsRepositoryProvider = Provider<CardsRepository>((ref) {
  final workspace = ref.watch(cardsWorkspaceProvider);
  if (workspace == null) throw StateError('Cards are not ready yet.');
  return workspace;
});

final studyQueueServiceProvider = Provider<StudyQueueService>((ref) {
  return StudyQueueService(ref.watch(clockProvider));
});

final cardSchedulerProvider = Provider<CardScheduler>((ref) {
  return FsrsCardScheduler();
});

final cardAudioRepositoryProvider = Provider<CardAudioRepository?>((ref) {
  final user = ref.watch(authProvider).value;
  final session = ref.watch(activeCardsSessionProvider).value;
  final preset = user?.preset ?? BackendPreset.fromKey(session?.route);
  final baseUrl = preset == null ? null : resolve(preset).imageHttp;
  final userId = user?.userId ?? session?.userId;
  if (baseUrl == null || userId == null) return null;
  final remote = HttpCardAudioRepository(baseUrl: baseUrl, userId: userId);
  if (!ref.watch(cardsOfflineEnabledProvider)) return remote;
  if (session == null) return remote;
  final safeName = session.account.key.replaceAll(
    RegExp(r'[^a-zA-Z0-9_]'),
    '_',
  );
  final manager = CacheManager(Config('nx_cards_audio_$safeName'));
  ref.onDispose(manager.dispose);
  return CachedCardAudioRepository(
    remote: remote,
    cache: FlutterCardAudioByteCache(manager),
  );
});

final cardsSchemaStatusProvider = FutureProvider<CardsSchemaStatus>((ref) {
  if (ref.watch(cardsOfflineEnabledProvider)) {
    return Future<CardsSchemaStatus>.value(
      const CardsSchemaStatus(cardReady: true, languageCardReady: true),
    );
  }
  return inspectCardsSchema(ref.watch(graphqlClientProvider));
});

final cardsDashboardProvider = StreamProvider<CardsDashboard>((ref) {
  final workspace = ref.watch(cardsWorkspaceProvider);
  if (workspace == null) {
    return Stream<CardsDashboard>.value(
      const CardsDashboard(cards: <StudyCard>[]),
    );
  }
  return workspace.watchDashboard();
});

final languagesProvider = FutureProvider<List<String>>((ref) {
  final workspace = ref.watch(cardsWorkspaceProvider);
  return workspace?.listLanguages() ?? Future<List<String>>.value(const []);
});

final relatedBooksProvider = FutureProvider<List<RelatedBook>>((ref) {
  final workspace = ref.watch(cardsWorkspaceProvider);
  return workspace?.listBooks() ?? Future<List<RelatedBook>>.value(const []);
});

typedef CardsLibrarySync = Future<void> Function();
typedef CardsFullSync = Future<int> Function();

final cardsLibrarySyncProvider = Provider<CardsLibrarySync>((ref) {
  return () async {
    final workspace = ref.read(cardsWorkspaceProvider);
    if (workspace == null) throw StateError('Cards are not ready yet.');
    if (ref.read(cardsOfflineEnabledProvider)) {
      await workspace.syncLibrary();
    } else {
      ref.invalidate(cardsDashboardProvider);
    }
  };
});

/// Forces a network-backed library snapshot and reports the resulting local
/// card count. Unlike lifecycle sync, callers receive any error so they can
/// surface it to the user.
final cardsFullSyncProvider = Provider<CardsFullSync>((ref) {
  return () async {
    final workspace = ref.read(cardsWorkspaceProvider);
    if (workspace == null) throw StateError('Cards are not ready yet.');
    await workspace.syncLibrary();
    return (await workspace.listCards()).length;
  };
});

final cardsLifecycleSyncProvider = Provider<offline.OfflineSynchronize?>((ref) {
  if (!ref.watch(cardsOfflineEnabledProvider)) return null;
  final workspace = ref.watch(cardsWorkspaceProvider);
  if (workspace == null) return null;
  return (_) => workspace.syncLibrary();
});

final cardsConnectivityChangesProvider = Provider<Stream<bool>?>((ref) {
  if (!ref.watch(cardsOfflineEnabledProvider)) return null;
  return Connectivity().onConnectivityChanged
      .map(
        (results) => results.any((result) => result != ConnectivityResult.none),
      )
      .distinct();
});

void invalidateCardsData(Ref ref) {
  if (!ref.read(cardsOfflineEnabledProvider)) {
    ref.invalidate(cardsDashboardProvider);
  }
  ref.invalidate(languagesProvider);
  ref.invalidate(relatedBooksProvider);
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}
