import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/application/native/card_outbox_contract.dart';
import 'package:nx_cards/data/local/drift/cards_database.dart';
import 'package:nx_cards/data/local/drift/drift_local_cards_store.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_offline/nx_offline.dart';

void main() {
  late CardsDatabase database;
  late DriftLocalCardsStore store;
  const account = AccountIdentity(
    serverId: 'nexus-primary',
    userId: '1',
    application: 'nx_cards',
  );

  setUp(() {
    database = CardsDatabase(NativeDatabase.memory());
    store = DriftLocalCardsStore(database: database, account: account);
  });

  tearDown(() => database.close());

  test('imports a canonical deck aggregate into typed local tables', () async {
    await store.applySyncBundle(_bundle(hash: 'hash-1'));

    final dashboard = await store.readDashboard();

    expect(dashboard.decks.single.name, 'Malayalam');
    expect(dashboard.cards.single.front, 'talent');
    expect(dashboard.cards.single.content, isA<LanguageCardContent>());
    expect(
      (dashboard.cards.single.content as LanguageCardContent).audioUrl,
      '/cards/audio/1/11.mp3',
    );
    expect(await store.deckManifest(), hasLength(1));
    expect((await store.deckManifest()).single.serverHash, 'hash-1');
  });

  test('domain update and durable outbox enqueue commit atomically', () async {
    await store.applySyncBundle(_bundle(hash: 'hash-1'));
    final original = (await store.readDashboard()).cards.single;
    final edited = original.copyWith(
      schedules: <StudyDirection, CardSchedule>{
        ...original.schedules,
        StudyDirection.frontToBack: original
            .scheduleFor(StudyDirection.frontToBack)
            .copyWith(
              reviewCount: 1,
              lastReviewedAt: DateTime.utc(2026, 8, 4, 12),
            ),
      },
      updatedAt: DateTime.utc(2026, 8, 4, 12),
    );

    await store.saveCardAndEnqueue(
      edited,
      operationId: 'operation-1',
      mutationType: MutationType.update,
      createdAt: DateTime.utc(2026, 8, 4, 12),
    );

    expect(
      (await store.readDashboard()).cards.single
          .scheduleFor(StudyDirection.frontToBack)
          .reviewCount,
      1,
    );
    final pending = await store.pendingMutations();
    expect(pending, hasLength(1));
    expect(pending.single.operationId, 'operation-1');
    expect(pending.single.entityKey.remoteId, 11);
  });

  test(
    'remote bundle does not overwrite a different pending local edit',
    () async {
      await store.applySyncBundle(_bundle(hash: 'hash-1'));
      final original = (await store.readDashboard()).cards.single;
      await store.saveCardAndEnqueue(
        original.copyWith(
          content: const LanguageCardContent(
            english: 'local talent',
            originalScript: 'കഴിവ്',
            transliteration: 'kazhivu',
            audioUrl: '/cards/audio/1/11.mp3',
          ),
        ),
        operationId: 'operation-1',
        mutationType: MutationType.update,
        createdAt: DateTime.utc(2026, 8, 4, 12),
      );

      await store.applySyncBundle(
        _bundle(hash: 'hash-2', front: 'remote talent'),
      );

      expect((await store.readDashboard()).cards.single.front, 'local talent');
      expect((await store.deckManifest()).single.serverHash, 'hash-2');
    },
  );

  test(
    'receipt removes its operation and applies canonical aggregate',
    () async {
      await store.applySyncBundle(_bundle(hash: 'hash-1'));
      final original = (await store.readDashboard()).cards.single;
      await store.saveCardAndEnqueue(
        original.copyWith(
          schedules: <StudyDirection, CardSchedule>{
            ...original.schedules,
            StudyDirection.frontToBack: original
                .scheduleFor(StudyDirection.frontToBack)
                .copyWith(reviewCount: 1),
          },
        ),
        operationId: 'operation-1',
        mutationType: MutationType.update,
        createdAt: DateTime.utc(2026, 8, 4, 12),
      );

      await store.complete(
        MutationReceipt(
          operationId: 'operation-1',
          entityKey: const EntityKey(localId: 'card:11', remoteId: 11),
          revision: const Revision('2026-08-04T12:00:00Z'),
          metadata: <String, Object?>{
            cardSyncBundleMetadataKey: _bundle(
              hash: 'hash-2',
              front: 'canonical talent',
            ),
          },
        ),
      );

      expect(await store.pendingMutations(), isEmpty);
      expect(
        (await store.readDashboard()).cards.single.front,
        'canonical talent',
      );
      expect((await store.deckManifest()).single.serverHash, 'hash-2');
    },
  );

  test('account partitions do not share rows', () async {
    await store.applySyncBundle(_bundle(hash: 'hash-1'));
    final other = DriftLocalCardsStore(
      database: database,
      account: const AccountIdentity(
        serverId: 'nexus-primary',
        userId: '2',
        application: 'nx_cards',
      ),
    );

    expect((await other.readDashboard()).decks, isEmpty);
    expect(await other.pendingMutations(), isEmpty);
  });

  test('cached library and pending edits survive a process restart', () async {
    // This test owns a file-backed database instead of the memory database
    // created by setUp.
    await database.close();
    final directory = await Directory.systemTemp.createTemp(
      'nx-cards-restart-test-',
    );
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final file = File('${directory.path}/cards.sqlite');

    final firstDatabase = CardsDatabase(NativeDatabase(file));
    final firstStore = DriftLocalCardsStore(
      database: firstDatabase,
      account: account,
    );
    await firstStore.applySyncBundle(_bundle(hash: 'hash-1'));
    final original = (await firstStore.readDashboard()).cards.single;
    await firstStore.saveCardAndEnqueue(
      original.copyWith(
        content: const LanguageCardContent(
          english: 'ability',
          originalScript: 'കഴിവ്',
          transliteration: 'kazhivu',
          audioUrl: '/cards/audio/1/11.mp3',
        ),
      ),
      operationId: 'survives-restart',
      mutationType: MutationType.update,
      createdAt: DateTime.utc(2026, 8, 4, 12),
    );
    await firstDatabase.close();

    final secondDatabase = CardsDatabase(NativeDatabase(file));
    addTearDown(secondDatabase.close);
    final secondStore = DriftLocalCardsStore(
      database: secondDatabase,
      account: account,
    );

    final restored = await secondStore.readDashboard();
    expect(restored.decks.single.name, 'Malayalam');
    expect(restored.cards.single.front, 'ability');
    expect(
      (await secondStore.pendingMutations()).single.operationId,
      'survives-restart',
    );
  });
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
            schedules: const <StudyDirection, CardSchedule>{
              StudyDirection.frontToBack: CardSchedule.initial(enabled: true),
              StudyDirection.backToFront: CardSchedule.initial(enabled: true),
            },
            reviewHistory: const <StudyDirection, List<CardReview>>{
              StudyDirection.frontToBack: <CardReview>[],
              StudyDirection.backToFront: <CardReview>[],
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
