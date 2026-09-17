import 'package:connectivity_plus/connectivity_plus.dart';
import 'expense_assets.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/app_reads.dart';
import 'package:nx_db/app_session.dart';
import 'package:nx_db/app_sync.dart';
import 'package:nx_db/nx_db.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:nx_offline/nx_offline_storage.dart';
import 'expense_data_repository.dart';
import 'expense_store.dart';
import 'expense_synchronizer.dart';
import 'expense_transport.dart';
import 'expense_receipts.dart';

final expenseOfflineStoreProvider = Provider<ExpenseStore?>((ref) {
  if (!AppDataPolicy.current.storesOfflineData) return null;
  final user = ref.watch(authProvider).value;
  if (user == null || user.domainId == null) return null;
  final account = AccountIdentity(
    serverId: user.preset.serverId,
    userId: user.userId,
    domainId: user.requiredDomainId,
    application: 'nx_expense_v2',
  );
  final library = FileLibrary.application(account.key);
  final store = ExpenseStore(library, account);
  ref.onDispose(() => unawaited(store.close()));
  return store;
});

final expenseTransportProvider = Provider<ExpenseTransport?>((ref) {
  if (ref.watch(authProvider).value?.domainId == null) return null;
  final reads = ref.watch(appReadsProvider('expense'));
  return reads == null ? null : ExpenseTransport(reads);
});

final expenseOutboxProvider = Provider<OutboxProcessor?>((ref) {
  final store = ref.watch(expenseOfflineStoreProvider);
  final remote = ref.watch(expenseTransportProvider);
  if (store == null || remote == null) return null;
  const clock = SystemClock();
  final uploader = OutboxProcessor(
    store: store,
    handlers: [
      ExpenseMutationHandler(store, remote),
      ExpenseReceiptHandler(
        store,
        remote,
        BinaryContentFiles.application(store.account.key),
      ),
    ],
    clock: clock,
    workerId: expenseOperationId(),
    scheduler: RetryScheduler(clock: clock),
  );
  Future<void>? closing;
  Future<void> close() => closing ??= uploader.close();
  store.beforeClose.add(close);
  ref.onDispose(() => unawaited(close()));
  return uploader;
});

final expenseLibrarySyncProvider = Provider<SyncSupervisor<int>?>((ref) {
  final store = ref.watch(expenseOfflineStoreProvider);
  if (store == null) return null;
  final uploader = ref.watch(expenseOutboxProvider);
  final assets = ref.watch(expenseAssetsProvider);
  final sync = SyncSupervisor<int>(
    reconciler: ExpenseReconciler(
      store,
      AppSyncClient(ref.watch(graphqlClientProvider), 'expense').session,
      onChanged: () {
        if (ref.mounted) {
          ref.read(expenseDataGenerationProvider.notifier).changed();
        }
      },
      syncAssets: () async {
        await assets?.synchronize(await store.all());
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
final expenseDataGenerationProvider =
    NotifierProvider<ExpenseDataGeneration, int>(ExpenseDataGeneration.new);

class ExpenseDataGeneration extends Notifier<int> {
  @override
  int build() => 0;
  void changed() => state++;
}

final expenseDataRepositoryProvider = Provider<ExpenseDataRepository?>((ref) {
  final remote = ref.watch(expenseTransportProvider);
  final user = ref.watch(authProvider).value;
  if (remote == null || user?.domainId == null) return null;
  return ExpenseDataRepository(
    reads: remote.reads,
    remote: remote,
    domainId: user!.requiredDomainId,
    store: ref.watch(expenseOfflineStoreProvider),
    onPending: () => ref.read(expenseOutboxProvider)?.schedule(),
    onChanged: () {
      if (ref.mounted) {
        ref.read(expenseDataGenerationProvider.notifier).changed();
      }
    },
  );
});

final expenseDataSessionProvider = Provider<AppDataSession?>((ref) {
  final sync = ref.watch(expenseLibrarySyncProvider);
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
      name: 'expense',
      refreshVisible: () async {
        ref.read(appReadsProvider('expense'))?.invalidate();
        if (ref.mounted) {
          ref.read(expenseDataGenerationProvider.notifier).changed();
        }
      },
    ),
    offline: sync == null
        ? null
        : PersistentSyncBackend((reason) async {
            await sync.requestFull(reason);
          }),
  );
});

final expenseReceiptsProvider = Provider<ExpenseReceipts?>((ref) {
  final remote = ref.watch(expenseTransportProvider);
  final user = ref.watch(authProvider).value;
  if (remote == null || user?.domainId == null) return null;
  final store = ref.watch(expenseOfflineStoreProvider);
  return ExpenseReceipts(
    remote,
    user!.requiredDomainId,
    store: store,
    files: store == null
        ? null
        : BinaryContentFiles.application(store.account.key),
    onPending: () {
      ref.read(expenseOutboxProvider)?.schedule();
      if (ref.mounted) {
        ref.read(expenseDataGenerationProvider.notifier).changed();
      }
    },
  );
});

final expenseAssetsProvider = Provider<ExpenseAssets?>((ref) {
  final remote = ref.watch(expenseTransportProvider);
  if (remote == null) return null;
  final store = ref.watch(expenseOfflineStoreProvider);
  final assets = ExpenseAssets(
    client: remote.reads.client,
    origin: remote.reads.origin,
    library: store?.library,
    files: store == null
        ? null
        : BinaryContentFiles.application(store.account.key),
  );
  if (store != null) store.beforeClose.add(assets.close);
  ref.onDispose(() => unawaited(assets.close()));
  return assets;
});
