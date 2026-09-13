// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:nx_cards/sync/native/cards_uploader.dart';
import 'package:nx_cards/sync/remote/cards_sync_transport.dart';
import 'package:nx_cards/sync/native/local_cards_store.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_offline/nx_offline.dart';

final class CardLibrarySynchronizer {
  CardLibrarySynchronizer({
    required LocalCardsStore localStore,
    required CardsSyncTransport? transport,
    required CardsUploader? uploader,
    CardAudioRepository? audioRepository,
  }) : _localStore = localStore,
       _transport = transport,
       _audioRepository = audioRepository {
    _supervisor = SyncSupervisor<int>(
      reconciler: _CardPullReconciler(
        localStore: localStore,
        requireTransport: _requireTransport,
        afterPull: () => unawaited(prefetchAudio()),
      ),
      prepare: uploader?.uploadPending,
      coalescingWindow: Duration.zero,
    );
  }

  final LocalCardsStore _localStore;
  final CardsSyncTransport? _transport;
  final CardAudioRepository? _audioRepository;
  late final SyncSupervisor<int> _supervisor;

  Future<void> syncLibrary({SyncReason reason = SyncReason.manual}) {
    return _supervisor.requestFull(reason);
  }

  CardsSyncTransport _requireTransport() {
    final transport = _transport;
    if (transport == null) {
      throw StateError(
        'The remote Cards service is unavailable while offline.',
      );
    }
    return transport;
  }

  /// Downloads every locally referenced pronunciation that is not cached yet.
  ///
  /// This deliberately reads the local store instead of only inspecting the
  /// latest sync bundle. A transient download failure must be retried by the
  /// next sync even when the card snapshot has not changed.
  Future<void>? _audioPrefetch;

  Future<void> prefetchAudio() => _audioPrefetch ??= _prefetchAudio()
      .whenComplete(() => _audioPrefetch = null);

  Future<void> _prefetchAudio() async {
    final repository = _audioRepository;
    if (repository == null) return;
    final cards = (await _localStore.readDashboard()).cards;
    final urls = <String>{};
    for (final summary in cards) {
      final card = await _localStore.getCard(summary.id);
      if (card?.content case final LanguageCardContent content) {
        urls.addAll({
          if (content.audioUrl case final url? when url.isNotEmpty) url,
          for (final example in content.examples)
            if (example.audioUrl case final url? when url.isNotEmpty) url,
        });
      }
    }
    final list = urls.toList();
    for (var offset = 0; offset < list.length; offset += 4) {
      await Future.wait(
        list
            .skip(offset)
            .take(4)
            .map((url) => _downloadAudio(repository, {url})),
      );
    }
  }

  Future<void> _downloadAudio(
    CardAudioRepository repository,
    Set<String> urls,
  ) async {
    for (final url in urls) {
      try {
        await repository.fetch(url);
      } catch (_) {
        // Audio is opportunistic; card data remains usable without it.
      }
    }
  }

  Future<void> close() => _supervisor.close();
}

final class _CardPullReconciler implements PullReconciler<int> {
  const _CardPullReconciler({
    required LocalCardsStore localStore,
    required CardsSyncTransport Function() requireTransport,
    required void Function() afterPull,
  }) : _localStore = localStore,
       _requireTransport = requireTransport,
       _afterPull = afterPull;

  final LocalCardsStore _localStore;
  final CardsSyncTransport Function() _requireTransport;
  final void Function() _afterPull;

  @override
  Future<void> pullAll() async {
    final transport = _requireTransport();
    final store = _localStore;
    if (transport is HashCardsSyncTransport && store is HashCardsStore) {
      final hashTransport = transport as HashCardsSyncTransport;
      final hashStore = store as HashCardsStore;
      final generation = hashStore.editGeneration;
      final remote = await hashTransport.cardManifest();
      final manifest = await reconcileHashManifest<int, CardHash, HashedCard>(
        manifest: remote.manifest,
        keyOf: (entry) => entry.id,
        valueKeyOf: (entry) => entry.card.id,
        verified: hashStore.verifiedCard,
        download: (ids) async {
          final bundle = await hashTransport.downloadCards(ids);
          return HashDownload(bundle.cards, deleted: bundle.deletedIds);
        },
        applyBatch: (page) =>
            hashStore.applyCardBatch(page, expectedGeneration: generation),
      );
      await hashStore.publishCardManifest(
        manifest,
        expectedGeneration: generation,
      );
    } else {
      await store.applyCardSnapshot(await transport.syncCards());
    }
    _afterPull();
  }

  @override
  Future<void> pullKeys(Set<int> keys) => pullAll();
}
