import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/account/account_session.dart';
import 'package:nx_cards/audio/audio_providers.dart';
import 'package:nx_cards/scheduling/scheduling.dart';
import 'package:nx_cards/sync/card_synchronizer.dart';
import 'package:nx_cards/sync/native/cards_database.dart';
import 'package:nx_cards/sync/native/cards_uploader.dart';
import 'package:nx_cards/sync/native/drift_local_cards_store.dart';
import 'package:nx_cards/sync/native/local_cards_store.dart';
import 'package:nx_cards/sync/remote/cards_sync_transport.dart';
import 'package:nx_cards/sync/remote/kgql_sync_transport.dart';
import 'package:nx_db/nx_db.dart';
import 'package:nx_offline/nx_offline.dart' as offline;

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

final cardsConnectivityChangesProvider = Provider<Stream<bool>?>((ref) {
  if (!ref.watch(cardsOfflineEnabledProvider)) return null;
  return Connectivity().onConnectivityChanged
      .map(
        (results) => results.any((result) => result != ConnectivityResult.none),
      )
      .distinct();
});

offline.OfflineSynchronize synchronizeWorkspace(
  Future<void> Function() synchronize,
) =>
    (_) => synchronize();
