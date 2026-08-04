// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:nx_cards/application/native/cards_uploader.dart';
import 'package:nx_cards/application/ports/cards_sync_transport.dart';
import 'package:nx_cards/application/ports/local_cards_store.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_cards/domain/card/card_audio_repository.dart';
import 'package:nx_offline/nx_offline.dart';

final class CardDeckSynchronizer {
  CardDeckSynchronizer({
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
  final ReconciliationCoordinator<int, CardDeck?> _runs =
      ReconciliationCoordinator<int, CardDeck?>();

  Future<void> syncLibrary() => _runs.runFull(_syncLibraryOnce);

  Future<void> _syncLibraryOnce() async {
    final transport = _requireTransport();
    await _uploader?.uploadPending();
    final manifest = await _localStore.deckManifest();
    final bundle = await transport.syncDecks(manifest: manifest);
    await _localStore.applySyncBundle(bundle);
    _prefetchAudio(bundle);
  }

  Future<CardDeck?> syncDeck(int deckId) => _runs.runItem(
    deckId,
    reconcile: () => _syncDeckOnce(deckId),
    readAfterFull: () => _localStore.getDeck(deckId),
  );

  Future<CardDeck?> _syncDeckOnce(int deckId) async {
    final transport = _requireTransport();
    await _uploader?.uploadPending();
    final bundle = await transport.syncDecks(
      manifest: await _localStore.deckManifest(deckIds: <int>{deckId}),
      deckIds: <int>{deckId},
    );
    await _localStore.applySyncBundle(bundle);
    _prefetchAudio(bundle);
    return _localStore.getDeck(deckId);
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

  void _prefetchAudio(CardDeckSyncBundle bundle) {
    final repository = _audioRepository;
    if (repository == null) return;
    final urls = <String>{
      for (final deck in bundle.decks)
        for (final card in deck.cards)
          if (card.content case final LanguageCardContent content)
            if (content.audioUrl case final url? when url.isNotEmpty) url,
    };
    unawaited(_downloadAudio(repository, urls));
  }

  Future<void> _downloadAudio(
    CardAudioRepository repository,
    Set<String> urls,
  ) async {
    for (final url in urls) {
      try {
        await repository.fetch(url);
      } catch (_) {
        // Audio is opportunistic; deck data remains usable without it.
      }
    }
  }
}
