import 'package:nx_people/data/sync/people_assets.dart';
import 'package:nx_people/data/sync/people_sync_telemetry.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/app_reads.dart';
import 'package:nx_db/app_session.dart';
import 'package:nx_db/app_sync.dart';
import 'package:nx_db/nx_db.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:nx_offline/nx_offline_storage.dart';
import 'package:nx_people/data/sync/people_data_repository.dart';
import 'package:nx_people/data/sync/people_store.dart';
import 'package:nx_people/data/sync/people_synchronizer.dart';
import 'package:nx_people/data/sync/people_transport.dart';

final peopleOfflineStoreProvider = Provider<PeopleStore?>((ref) {
  if (!AppDataPolicy.current.storesOfflineData) return null;
  final user = ref.watch(authProvider).value;
  if (user == null || user.domainId == null) return null;
  final account = AccountIdentity(
    serverId: user.preset.serverId,
    userId: user.userId,
    domainId: user.requiredDomainId,
    application: 'nx_people_v1',
  );
  final library = FileLibrary.application(account.key);
  final store = PeopleStore(library, account);
  final subscription = store.changes.listen((_) {
    if (ref.mounted) ref.read(peopleDataGenerationProvider.notifier).changed();
  });
  ref.onDispose(() => unawaited(subscription.cancel()));
  ref.onDispose(() => unawaited(store.close()));
  return store;
});

final peopleTransportProvider = Provider<PeopleTransport?>((ref) {
  if (ref.watch(authProvider).value?.domainId == null) return null;
  final reads = ref.watch(appReadsProvider('people'));
  return reads == null ? null : PeopleTransport(reads);
});

final peopleOutboxProvider = Provider<OutboxProcessor?>((ref) {
  final store = ref.watch(peopleOfflineStoreProvider);
  final remote = ref.watch(peopleTransportProvider);
  if (store == null || remote == null) return null;
  const clock = SystemClock();
  final uploader = OutboxProcessor(
    store: store,
    handlers: [
      PeopleMutationHandler(
        store,
        remote,
        assets: ref.watch(peopleAssetsProvider),
      ),
    ],
    clock: clock,
    workerId: peopleOperationId(),
    scheduler: RetryScheduler(clock: clock),
  );
  Future<void>? closing;
  Future<void> close() => closing ??= uploader.close();
  store.beforeClose.add(close);
  ref.onDispose(() => unawaited(close()));
  return uploader;
});

final peopleLibrarySyncProvider = Provider<SyncSupervisor<int>?>((ref) {
  final store = ref.watch(peopleOfflineStoreProvider);
  if (store == null) return null;
  final uploader = ref.watch(peopleOutboxProvider);
  final assets = ref.watch(peopleAssetsProvider);
  final telemetry = ref.watch(peopleSyncTelemetryProvider);
  final sync = SyncSupervisor<int>(
    reconciler: PeopleReconciler(
      store,
      AppSyncClient(
        ref.watch(graphqlClientProvider),
        'people',
        telemetry: telemetry?.record,
      ).session,
      telemetry: telemetry?.record,
      syncAssets: () async {
        // Media cannot hold up a later log/profile invalidation.
        unawaited(assets!.synchronize(await store.all()));
      },
      onChanged: () {
        if (ref.mounted) {
          ref.read(peopleDataGenerationProvider.notifier).changed();
        }
      },
    ),
    prepare: () async {
      await uploader?.process();
    },
    retryDelay: const Duration(seconds: 5),
  );
  Future<void>? closing;
  Future<void> close() => closing ??= sync.close();
  store.beforeClose.add(close);
  ref.onDispose(() => unawaited(close()));
  return sync;
});

/// Screens can observe this generation without tying reads to network status.
final peopleDataGenerationProvider =
    NotifierProvider<PeopleDataGeneration, int>(PeopleDataGeneration.new);

class PeopleDataGeneration extends Notifier<int> {
  @override
  int build() => 0;
  void changed() => state++;
}

final peopleDataRepositoryProvider = Provider<PeopleDataRepository?>((ref) {
  final remote = ref.watch(peopleTransportProvider);
  final user = ref.watch(authProvider).value;
  if (remote == null || user?.domainId == null) return null;
  return PeopleDataRepository(
    reads: remote.reads,
    remote: remote,
    domainId: user!.requiredDomainId,
    store: ref.watch(peopleOfflineStoreProvider),
    onPending: () {
      if (ref.mounted) ref.read(peopleOutboxProvider)?.schedule();
    },
    onChanged: () {
      if (ref.mounted) {
        ref.read(peopleDataGenerationProvider.notifier).changed();
      }
    },
  );
});

final peopleDataSessionProvider = Provider<AppDataSession?>((ref) {
  final sync = ref.watch(peopleLibrarySyncProvider);
  final telemetry = ref.watch(peopleSyncTelemetryProvider);
  return createAppSession(
    ref,
    onlineChanges: sync == null
        ? null
        : Connectivity().onConnectivityChanged
              .map(
                (results) =>
                    results.any((value) => value != ConnectivityResult.none),
              )
              .distinct(),
    definition: AppDataDefinition(
      name: 'people',
      refreshVisible: () async {
        ref.read(appReadsProvider('people'))?.invalidate();
        if (ref.mounted) {
          ref.read(peopleDataGenerationProvider.notifier).changed();
        }
      },
    ),
    offline: sync == null
        ? null
        : PersistentSyncBackend((reason) async {
            telemetry?.record('check_requested', {'reason': reason.toString()});
            await sync.requestFull(reason);
          }),
  );
});

final peopleAssetsProvider = Provider<PeopleAssets?>((ref) {
  final remote = ref.watch(peopleTransportProvider);
  final user = ref.watch(authProvider).value;
  if (remote == null || user?.domainId == null) return null;
  final store = ref.watch(peopleOfflineStoreProvider);
  final assets = PeopleAssets(
    remote,
    user!.requiredDomainId,
    store: store,
    files: store == null
        ? null
        : BinaryContentFiles.application(store.account.key),
  );
  if (store != null) store.beforeClose.add(assets.close);
  ref.onDispose(() => unawaited(assets.close()));
  return assets;
});
