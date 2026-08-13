import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/account/account_session.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/browser/data/kgql/kgql_card_api.dart';
import 'package:nx_cards/browser/data/kgql/kgql_card_schema.dart';
import 'package:nx_cards/scheduling/scheduling.dart';
import 'package:nx_cards/sync/native/native_card_library.dart';
import 'package:nx_cards/sync/remote/remote_card_library.dart';
import 'package:nx_cards/sync/sync_providers.dart';
import 'package:nx_db/nx_db.dart';
import 'package:nx_offline/nx_offline.dart' as offline;

final kgqlCardApiProvider = Provider<CardLibrary?>((ref) {
  if (ref.watch(authProvider).value == null) return null;
  return KgqlCardApi(ref.watch(graphqlClientProvider));
});

final cardWorkspaceProvider = Provider<CardWorkspace?>((ref) {
  final CardWorkspace? workspace;
  if (ref.watch(cardsOfflineEnabledProvider)) {
    final local = ref.watch(localCardsStoreProvider);
    final synchronizer = ref.watch(cardLibrarySynchronizerProvider);
    if (local == null || synchronizer == null) return null;
    workspace = NativeCardLibrary(
      localStore: local,
      serverLibrary: ref.watch(kgqlCardApiProvider),
      transport: ref.watch(cardsSyncTransportProvider),
      uploader: ref.watch(cardsUploaderProvider),
      synchronizer: synchronizer,
      clock: ref.watch(clockProvider),
      newOperationId: ref.watch(cardsOperationIdProvider),
    );
  } else {
    final kgqlApi = ref.watch(kgqlCardApiProvider);
    if (kgqlApi == null) return null;
    workspace = RemoteCardLibrary(kgqlApi);
  }
  ref.onDispose(() => unawaited(workspace!.close()));
  return workspace;
});

final cardLibraryProvider = Provider<CardLibrary>((ref) {
  final workspace = ref.watch(cardWorkspaceProvider);
  if (workspace == null) throw StateError('Cards are not ready yet.');
  return workspace;
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
  final workspace = ref.watch(cardWorkspaceProvider);
  return workspace?.watchDashboard() ??
      Stream<CardsDashboard>.value(const CardsDashboard(cards: <StudyCard>[]));
});

final languagesProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(cardWorkspaceProvider)?.listLanguages() ??
      Future<List<String>>.value(const []);
});

final relatedBooksProvider = FutureProvider<List<RelatedBook>>((ref) {
  return ref.watch(cardWorkspaceProvider)?.listBooks() ??
      Future<List<RelatedBook>>.value(const []);
});

typedef CardsLibrarySync = Future<void> Function();
typedef CardsFullSync = Future<int> Function();

final cardsLibrarySyncProvider = Provider<CardsLibrarySync>((ref) {
  return () async {
    final workspace = ref.read(cardWorkspaceProvider);
    if (workspace == null) throw StateError('Cards are not ready yet.');
    if (ref.read(cardsOfflineEnabledProvider)) {
      await workspace.syncLibrary();
    } else {
      ref.invalidate(cardsDashboardProvider);
    }
  };
});

final cardsFullSyncProvider = Provider<CardsFullSync>((ref) {
  return () async {
    final workspace = ref.read(cardWorkspaceProvider);
    if (workspace == null) throw StateError('Cards are not ready yet.');
    await workspace.syncLibrary();
    return (await workspace.listCards()).length;
  };
});

final cardsLifecycleSyncProvider = Provider<offline.OfflineSynchronize?>((ref) {
  if (!ref.watch(cardsOfflineEnabledProvider)) return null;
  final workspace = ref.watch(cardWorkspaceProvider);
  if (workspace == null) return null;
  return synchronizeWorkspace(workspace.syncLibrary);
});

void invalidateCardsData(Ref ref) {
  if (!ref.read(cardsOfflineEnabledProvider)) {
    ref.invalidate(cardsDashboardProvider);
  }
  ref.invalidate(languagesProvider);
  ref.invalidate(relatedBooksProvider);
}
