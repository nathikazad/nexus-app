import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/domain/card/card_audio_repository.dart';
import 'package:nx_cards/application/native/cards_uploader.dart';
import 'package:nx_cards/application/native/native_cards_workspace.dart';
import 'package:nx_cards/application/ports/cards_sync_transport.dart';
import 'package:nx_cards/application/ports/clock.dart';
import 'package:nx_cards/application/sync/card_deck_synchronizer.dart';
import 'package:nx_cards/data/local/drift/cards_database.dart';
import 'package:nx_cards/data/local/drift/drift_local_cards_store.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_offline/nx_offline.dart' hide Clock;

void main() {
  late CardsDatabase database;
  late DriftLocalCardsStore store;
  late _FakeClock clock;
  const account = AccountIdentity(
    serverId: 'nexus-primary',
    userId: '1',
    application: 'nx_cards',
  );

  setUp(() async {
    database = CardsDatabase(NativeDatabase.memory());
    store = DriftLocalCardsStore(database: database, account: account);
    clock = _FakeClock(DateTime.utc(2026, 8, 4, 12));
    await store.applySyncBundle(_bundle(hash: 'hash-1'));
  });

  tearDown(() => database.close());

  test('renders cached dashboard and queues edits with no transport', () async {
    final synchronizer = CardDeckSynchronizer(
      localStore: store,
      transport: null,
      uploader: null,
    );
    final workspace = NativeCardsWorkspace(
      localStore: store,
      remoteRepository: null,
      transport: null,
      uploader: null,
      synchronizer: synchronizer,
      clock: clock,
      newOperationId: () => 'offline-operation',
    );

    final cached = await workspace.watchDashboard().first;
    expect(cached.decks.single.name, 'Malayalam');
    expect(cached.cards.single.front, 'talent');

    await workspace.updateCardContent(
      id: 11,
      content: const LanguageCardContent(
        english: 'ability',
        originalScript: 'കഴിവ്',
        transliteration: 'kazhivu',
      ),
    );

    expect((await store.readDashboard()).cards.single.front, 'ability');
    expect(await store.pendingMutations(), hasLength(1));
    await expectLater(workspace.syncLibrary(), throwsStateError);
  });

  test(
    'reconnect uploads pending edit then reconciles the card library',
    () async {
      final offlineWorkspace = NativeCardsWorkspace(
        localStore: store,
        remoteRepository: null,
        transport: null,
        uploader: null,
        synchronizer: CardDeckSynchronizer(
          localStore: store,
          transport: null,
          uploader: null,
        ),
        clock: clock,
        newOperationId: () => 'offline-operation',
      );
      await offlineWorkspace.updateCardContent(
        id: 11,
        content: const LanguageCardContent(
          english: 'ability',
          originalScript: 'കഴിവ്',
          transliteration: 'kazhivu',
        ),
      );

      final transport = _FakeTransport(serverBundle: _bundle(hash: 'hash-1'));
      final uploader = CardsUploader(
        localStore: store,
        transport: transport,
        clock: clock,
        workerId: 'worker-1',
        uploadDelay: Duration.zero,
      );
      addTearDown(uploader.close);
      final synchronizer = CardDeckSynchronizer(
        localStore: store,
        transport: transport,
        uploader: uploader,
      );

      await synchronizer.syncLibrary();

      expect(transport.mutatedCards.single.front, 'ability');
      expect(await store.pendingMutations(), isEmpty);
      expect((await store.readDashboard()).cards.single.front, 'ability');
      expect(transport.targetedDeckIds, isEmpty);
      expect(transport.syncCardsCalls, greaterThanOrEqualTo(1));
    },
  );

  test('server stale result discards older local edit', () async {
    final existing = (await store.readDashboard()).cards.single;
    await store.saveCardAndEnqueue(
      existing.copyWith(
        content: const LanguageCardContent(
          english: 'older local edit',
          originalScript: 'കഴിവ്',
          transliteration: 'kazhivu',
        ),
      ),
      operationId: 'stale-operation',
      mutationType: MutationType.update,
      createdAt: clock.now(),
    );
    final transport = _FakeTransport(
      serverBundle: _bundle(hash: 'hash-9', front: 'newer server edit'),
      mutationStatus: CardMutationStatus.stale,
    );
    final uploader = CardsUploader(
      localStore: store,
      transport: transport,
      clock: clock,
      workerId: 'worker-1',
      uploadDelay: Duration.zero,
    );
    addTearDown(uploader.close);

    await uploader.uploadPending();

    expect(await store.pendingMutations(), isEmpty);
    expect(
      (await store.readDashboard()).cards.single.front,
      'newer server edit',
    );
  });

  test('server stale result restores a locally deleted card', () async {
    final existing = (await store.readDashboard()).cards.single;
    await store.saveCardAndEnqueue(
      existing,
      operationId: 'stale-delete',
      mutationType: MutationType.delete,
      createdAt: clock.now(),
    );
    expect((await store.readDashboard()).cards, isEmpty);

    final transport = _FakeTransport(
      serverBundle: _bundle(hash: 'hash-9', front: 'newer server edit'),
      mutationStatus: CardMutationStatus.stale,
    );
    final uploader = CardsUploader(
      localStore: store,
      transport: transport,
      clock: clock,
      workerId: 'worker-1',
      uploadDelay: Duration.zero,
    );
    addTearDown(uploader.close);

    await uploader.uploadPending();

    expect(await store.pendingMutations(), isEmpty);
    expect(
      (await store.readDashboard()).cards.single.front,
      'newer server edit',
    );
  });

  test(
    'audio prefetch retries local URLs when deck hashes are unchanged',
    () async {
      final audio = _RetryingAudioRepository();
      final transport = _FakeTransport(serverBundle: _bundle(hash: 'hash-1'));
      final synchronizer = CardDeckSynchronizer(
        localStore: store,
        transport: transport,
        uploader: null,
        audioRepository: audio,
      );

      await synchronizer.prefetchAudio();
      await synchronizer.syncLibrary();
      await synchronizer.prefetchAudio();

      expect(audio.urls, <String>[
        '/cards/audio/1/11.mp3',
        '/cards/audio/1/11.mp3',
        '/cards/audio/1/11.mp3',
      ]);
      expect(transport.serverBundle.decks.single.serverHash, 'hash-1');
    },
  );
}

final class _FakeClock implements Clock {
  _FakeClock(this.value);

  DateTime value;

  @override
  DateTime now() => value;
}

final class _RetryingAudioRepository implements CardAudioRepository {
  final List<String> urls = <String>[];

  @override
  Future<Uint8List> fetch(String audioUrl) async {
    urls.add(audioUrl);
    if (urls.length == 1) throw StateError('transient failure');
    return Uint8List.fromList(<int>[1, 2, 3]);
  }
}

final class _FakeTransport implements CardsSyncTransport {
  _FakeTransport({
    required this.serverBundle,
    this.mutationStatus = CardMutationStatus.applied,
  });

  CardDeckSyncBundle serverBundle;
  final CardMutationStatus mutationStatus;
  final List<StudyCard> mutatedCards = <StudyCard>[];
  final List<int> deletedCardIds = <int>[];
  final List<Set<int>?> targetedDeckIds = <Set<int>?>[];
  int syncCardsCalls = 0;

  @override
  Future<CardMutationResult> mutateCard(
    StudyCard card, {
    required DateTime clientUpdatedAt,
  }) async {
    mutatedCards.add(card);
    if (mutationStatus == CardMutationStatus.applied) {
      serverBundle = _bundle(hash: 'hash-2', front: card.front);
    }
    return CardMutationResult(
      status: mutationStatus,
      entityId: card.id,
      updatedAt: clientUpdatedAt,
      deckHashes: <DeckHashRevision>[
        DeckHashRevision(
          deckId: card.deckId,
          serverHash: mutationStatus == CardMutationStatus.applied
              ? 'hash-2'
              : 'hash-9',
        ),
      ],
      deletedDeckIds: const <int>[],
    );
  }

  @override
  Future<CardDeckSyncBundle> syncDecks({
    required List<CardDeckManifestEntry> manifest,
    Set<int>? deckIds,
  }) async {
    targetedDeckIds.add(deckIds);
    final remote = serverBundle.decks.single;
    final localHash = manifest
        .where((value) => value.deckId == remote.deck.id)
        .firstOrNull
        ?.serverHash;
    if (localHash == remote.serverHash) {
      return const CardDeckSyncBundle.empty();
    }
    return serverBundle;
  }

  @override
  Future<List<StudyCard>> syncCards() async {
    syncCardsCalls += 1;
    return [for (final remote in serverBundle.decks) ...remote.cards];
  }

  @override
  Future<CardMutationResult> deleteCard(
    int cardId, {
    required DateTime clientUpdatedAt,
  }) async {
    deletedCardIds.add(cardId);
    return CardMutationResult(
      status: mutationStatus,
      entityId: cardId,
      updatedAt: clientUpdatedAt,
      deckHashes: <DeckHashRevision>[
        DeckHashRevision(
          deckId: 7,
          serverHash: serverBundle.decks.single.serverHash,
        ),
      ],
      deletedDeckIds: const <int>[],
    );
  }

  @override
  Future<CardMutationResult> createCard({
    required CardContent content,
    int? deckId,
    int? sourceBookId,
    required DateTime clientUpdatedAt,
  }) => throw UnimplementedError();

  @override
  Future<CardMutationResult> createDeck({
    required String name,
    required String description,
    String? fromLanguage,
    String? toLanguage,
    required DateTime clientUpdatedAt,
  }) => throw UnimplementedError();
}

CardDeckSyncBundle _bundle({required String hash, String front = 'talent'}) {
  final updatedAt = DateTime.utc(2026, 8, 4, 10);
  return CardDeckSyncBundle(
    decks: <RemoteCardDeck>[
      RemoteCardDeck(
        deck: CardDeck(
          id: 7,
          name: 'Malayalam',
          description: 'Basic words',
          fromLanguage: 'English',
          toLanguage: 'Malayalam',
          archived: false,
          updatedAt: updatedAt,
        ),
        cards: <StudyCard>[
          StudyCard(
            id: 11,
            content: LanguageCardContent(
              english: front,
              originalScript: 'കഴിവ്',
              transliteration: 'kazhivu',
              audioUrl: '/cards/audio/1/11.mp3',
            ),
            deckId: 7,
            deckName: 'Malayalam',
            schedules: const <StudyCue, CardSchedule>{
              StudyCue.fromLanguage: CardSchedule.initial(enabled: true),
              StudyCue.toLanguage: CardSchedule.initial(enabled: true),
              StudyCue.transliteration: CardSchedule.initial(enabled: true),
            },
            reviewHistory: const <StudyCue, List<CardReview>>{
              StudyCue.fromLanguage: <CardReview>[],
              StudyCue.toLanguage: <CardReview>[],
              StudyCue.transliteration: <CardReview>[],
            },
            suspended: false,
            updatedAt: updatedAt,
          ),
        ],
        serverHash: hash,
      ),
    ],
    deletedDeckIds: const <int>[],
  );
}
