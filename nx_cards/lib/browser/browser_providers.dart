import 'package:nx_db/app_session.dart';
import 'package:nx_cards/sync/native/local_cards_store.dart';
import 'package:nx_cards/sync/remote/cards_sync_transport.dart';
import 'package:nx_db/app_reads.dart';
import 'data/models/library_summary.dart';
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
  if (ref.watch(authProvider).value?.domainId == null) return null;
  return KgqlCardApi(
    ref.watch(graphqlClientProvider),
    reads: ref.watch(appReadsProvider('cards')),
  );
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
  // Catalog/schema provisioning belongs to the backend, not startup reads.
  return Future.value(
    const CardsSchemaStatus(cardReady: true, languageCardReady: true),
  );
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
    ref.invalidate(reviewProgressionSettingsProvider);
    final workspace = ref.read(cardWorkspaceProvider);
    if (workspace == null) throw StateError('Cards are not ready yet.');
    if (ref.read(cardsOfflineEnabledProvider)) {
      await workspace.syncLibrary();
    } else {
      invalidateCardsData(ref);
      await ref.read(cardsSourcesProvider.future);
    }
  };
});

final cardsFullSyncProvider = Provider<CardsFullSync>((ref) {
  return () async {
    ref.invalidate(reviewProgressionSettingsProvider);
    final workspace = ref.read(cardWorkspaceProvider);
    if (workspace == null) throw StateError('Cards are not ready yet.');
    await workspace.syncLibrary();
    return (await workspace.listCards()).length;
  };
});

// Active view queries belong to Cards; lifecycle and persistence belong to nx_data.
final _visibleCollectionsProvider = Provider(
  (ref) => <({String? language, int? bookId})>{},
);

final cardsDataSessionProvider = Provider<AppDataSession?>((ref) {
  final synchronizer = ref.watch(cardLibrarySynchronizerProvider);
  final reader = ref.watch(appReadsProvider('cards'));
  return createAppSession(
    ref,
    definition: AppDataDefinition(
      name: 'cards',
      refreshVisible: () async {
        ref.invalidate(reviewProgressionSettingsProvider);
        if (reader == null) return;
        await reader.read('initial');
        for (final source in ref.read(_visibleCollectionsProvider).toList()) {
          await _refreshCardCollection(ref, source);
        }
        if (ref.mounted) invalidateCardsData(ref, invalidateCache: false);
      },
    ),
    offline: synchronizer == null
        ? null
        : offline.PersistentSyncBackend(
            (reason) => synchronizer.syncLibrary(reason: reason),
          ),
    onlineChanges: ref.watch(cardsConnectivityChangesProvider),
  );
});

Future<List<StudyCard>> _refreshCardCollection(
  Ref ref,
  ({String? language, int? bookId}) source,
) async {
  final reader = ref.read(appReadsProvider('cards'));
  if (reader == null) return [];
  final local = ref.read(localCardsStoreProvider);
  final hashStore = local is HashCardsStore ? local as HashCardsStore : null;
  final generation = hashStore?.editGeneration;
  final cards = await KgqlCardApi.readCollection(reader, {
    if (source.language != null) 'tag_system': 'Language',
    if (source.language != null) 'tag': source.language!,
    if (source.bookId != null) 'book_id': '${source.bookId}',
  });
  await hashStore?.applyCardBatch([
    for (final card in cards) HashedCard(card, ''),
  ], expectedGeneration: generation);
  return cards;
}

void invalidateCardsData(Ref ref, {bool invalidateCache = true}) {
  if (invalidateCache && ref.exists(appReadsProvider('cards'))) {
    ref.read(appReadsProvider('cards'))?.invalidate();
  }
  ref.invalidate(cardsSourcesProvider);
  ref.invalidate(cardsCollectionProvider);
  if (!ref.read(cardsOfflineEnabledProvider)) {
    ref.invalidate(cardsDashboardProvider);
  }
  ref.invalidate(languagesProvider);
  ref.invalidate(relatedBooksProvider);
}

final cardBodyProvider = FutureProvider.autoDispose
    .family<StudyCard, StudyCard>((ref, summary) async {
      if (!summary.isSummary) return summary;
      final local = ref.watch(localCardsStoreProvider);
      final card = await local?.getCard(summary.id);
      if (card == null) {
        throw StateError('Card ${summary.id} is unavailable offline.');
      }
      return card;
    });

Future<StudyCard> hydrateStudyCard(WidgetRef ref, StudyCard card) async {
  if (!card.isSummary) return card;
  final local = ref.read(localCardsStoreProvider);
  final full = await local?.getCard(card.id);
  if (full == null) throw StateError('Card ${card.id} is unavailable offline.');
  return full;
}

final cardsSourcesProvider = StreamProvider<List<LibrarySource>>((ref) async* {
  final window =
      ref.watch(reviewProgressionSettingsProvider).value?.historyWindow ?? 10;
  final reader = ref.watch(appReadsProvider('cards'));
  final workspace = ref.watch(cardWorkspaceProvider);
  if (ref.watch(cardsOfflineEnabledProvider) && workspace != null) {
    final cached = await workspace.watchDashboard().first;
    if (cached.cards.isNotEmpty) {
      yield summarizeLibrary(cached, historyWindow: window);
    }
  }
  if (reader != null) {
    try {
      final response = await reader.read('initial');
      yield [
        for (final item in response['collections'] as List)
          LibrarySource.fromJson(item as Map),
      ];
      return;
    } catch (_) {
      if (!ref.read(cardsOfflineEnabledProvider)) rethrow;
    }
  }
  if (workspace != null) {
    yield* workspace.watchDashboard().map(
      (data) => summarizeLibrary(data, historyWindow: window),
    );
  }
});

/// Only the selected source is loaded on web. Native reads remain local.
final cardsCollectionProvider = StreamProvider.autoDispose
    .family<CardsDashboard, ({String? language, int? bookId})>((
      ref,
      source,
    ) async* {
      final observed = ref.read(_visibleCollectionsProvider);
      observed.add(source);
      ref.onDispose(() => observed.remove(source));
      if (ref.watch(cardsOfflineEnabledProvider)) {
        final workspace = ref.watch(cardWorkspaceProvider)!;
        Set<int>? visibleIds;
        var attempted = false;
        await for (final dashboard in workspace.watchDashboard()) {
          if (!attempted) {
            attempted = true;
            yield dashboard;
            try {
              final cards = await _refreshCardCollection(ref, source);
              visibleIds = cards.map((card) => card.id).toSet();
              // Re-read merged cards so pending local edits win over server data.
              final local = ref.read(localCardsStoreProvider)!;
              final merged = await Future.wait([
                for (final card in cards)
                  local.getCard(card.id).then((value) => value ?? card),
              ]);
              yield CardsDashboard(cards: merged);
            } catch (_) {
              yield dashboard;
            }
          } else {
            yield visibleIds == null
                ? dashboard
                : CardsDashboard(
                    cards: dashboard.cards
                        .where((card) => visibleIds!.contains(card.id))
                        .toList(),
                  );
          }
        }
        return;
      }
      final reader = ref.watch(appReadsProvider('cards'));
      if (reader == null) return;
      final cards = await KgqlCardApi.readCollection(reader, {
        if (source.language != null) 'tag_system': 'Language',
        if (source.language != null) 'tag': source.language!,
        if (source.bookId != null) 'book_id': '${source.bookId}',
      });
      yield CardsDashboard(cards: cards);
    });

final cardsInvalidationProvider = Provider<void Function()>(
  (ref) =>
      () => invalidateCardsData(ref),
);
