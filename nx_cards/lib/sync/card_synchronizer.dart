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
  Future<void> prefetchAudio() async {
    final repository = _audioRepository;
    if (repository == null) return;
    final cards = (await _localStore.readDashboard()).cards;
    final urls = <String>{
      for (final card in cards)
        if (card.content case final LanguageCardContent content) ...<String>{
          if (content.audioUrl case final url? when url.isNotEmpty) url,
          for (final example in content.examples)
            if (example.audioUrl case final url? when url.isNotEmpty) url,
        },
    };
    await _downloadAudio(repository, urls);
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
    await _localStore.applyCardSnapshot(await _requireTransport().syncCards());
    _afterPull();
  }

  @override
  Future<void> pullKeys(Set<int> keys) => pullAll();
}
