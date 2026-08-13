// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:nx_cards/application/native/cards_uploader.dart';
import 'package:nx_cards/application/ports/cards_sync_transport.dart';
import 'package:nx_cards/application/ports/local_cards_store.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/domain/card/card_audio_repository.dart';
import 'package:nx_offline/nx_offline.dart';

final class CardLibrarySynchronizer {
  CardLibrarySynchronizer({
    required LocalCardsStore localStore,
    required CardsSyncTransport? transport,
    required CardsUploader? uploader,
    CardAudioRepository? audioRepository,
  }) : _localStore = localStore,
       _transport = transport,
       _uploader = uploader,
       _audioRepository = audioRepository;

  final LocalCardsStore _localStore;
  final CardsSyncTransport? _transport;
  final CardsUploader? _uploader;
  final CardAudioRepository? _audioRepository;
  final ReconciliationCoordinator<int, void> _runs =
      ReconciliationCoordinator<int, void>();

  Future<void> syncLibrary() => _runs.runFull(_syncLibraryOnce);

  Future<void> _syncLibraryOnce() async {
    final transport = _requireTransport();
    await _uploader?.uploadPending();
    await _localStore.applyCardSnapshot(await transport.syncCards());
    unawaited(prefetchAudio());
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
}
