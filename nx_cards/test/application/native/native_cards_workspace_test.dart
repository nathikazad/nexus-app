import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
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
      tags: const <String>['Vocabulary'],
    );

    expect((await store.readDashboard()).cards.single.front, 'ability');
    expect(await store.pendingMutations(), hasLength(1));
    await expectLater(workspace.syncLibrary(), throwsStateError);
  });

  test(
    'reconnect uploads pending edit then reconciles the deck aggregate',
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
        tags: const <String>['Vocabulary'],
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
      expect((await store.deckManifest()).single.serverHash, 'hash-2');
      expect(
        transport.targetedDeckIds.whereType<Set<int>>(),
        contains(
          predicate<Set<int>>((ids) => ids.length == 1 && ids.first == 7),
        ),
      );
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
}

final class _FakeClock implements Clock {
  _FakeClock(this.value);

  DateTime value;

  @override
  DateTime now() => value;
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
    required int deckId,
    required List<String> tags,
    int? sourceBookId,
    required DateTime clientUpdatedAt,
  }) => throw UnimplementedError();

  @override
  Future<CardMutationResult> createDeck({
    required String name,
    required String description,
    String? language,
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
          language: 'Malayalam',
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
            tags: const <String>['Vocabulary'],
            dueAt: null,
            lastReviewedAt: null,
            stability: null,
            difficulty: null,
            schedulingState: 'learning',
            learningStep: 0,
            suspended: false,
            reviewCount: 0,
            lapseCount: 0,
            updatedAt: updatedAt,
          ),
        ],
        serverHash: hash,
      ),
    ],
    deletedDeckIds: const <int>[],
  );
}
