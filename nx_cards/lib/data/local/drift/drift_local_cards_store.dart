import 'dart:async';

import 'package:drift/drift.dart';
import 'package:nx_cards/application/native/card_outbox_contract.dart';
import 'package:nx_cards/application/ports/local_cards_store.dart';
import 'package:nx_cards/data/local/drift/cards_database.dart';
import 'package:nx_cards/data/local/drift/drift_cards_mapper.dart';
import 'package:nx_cards/domain/cards_models.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:nx_offline/nx_offline_drift.dart';

final class DriftLocalCardsStore implements LocalCardsStore {
  const DriftLocalCardsStore({
    required this.database,
    required this.account,
    this.mapper = const DriftCardsMapper(),
  });

  final CardsDatabase database;
  @override
  final AccountIdentity account;
  final DriftCardsMapper mapper;

  String get _accountKey => account.key;
  DriftOutboxPersistence get _outbox =>
      DriftOutboxPersistence(database: database, account: account);

  @override
  Stream<CardsDashboard> watchDashboard() {
    final deckStream = (database.select(
      database.localCardDecks,
    )..where((table) => table.accountKey.equals(_accountKey))).watch();
    final cardStream =
        (database.select(database.localStudyCards)..where(
              (table) =>
                  table.accountKey.equals(_accountKey) &
                  table.deletedLocally.equals(false),
            ))
            .watch();
    return Stream<CardsDashboard>.multi((controller) {
      List<LocalCardDeckRow>? decks;
      List<LocalStudyCardRow>? cards;
      void emit() {
        final deckRows = decks;
        final cardRows = cards;
        if (deckRows != null && cardRows != null) {
          controller.add(_dashboard(deckRows, cardRows));
        }
      }

      final deckSubscription = deckStream.listen((value) {
        decks = value;
        emit();
      }, onError: controller.addError);
      final cardSubscription = cardStream.listen((value) {
        cards = value;
        emit();
      }, onError: controller.addError);
      controller.onCancel = () async {
        await deckSubscription.cancel();
        await cardSubscription.cancel();
      };
    });
  }

  @override
  Future<CardsDashboard> readDashboard() async {
    final results = await Future.wait(<Future<List<Object>>>[
      (database.select(
        database.localCardDecks,
      )..where((table) => table.accountKey.equals(_accountKey))).get(),
      (database.select(database.localStudyCards)..where(
            (table) =>
                table.accountKey.equals(_accountKey) &
                table.deletedLocally.equals(false),
          ))
          .get(),
    ]);
    return _dashboard(
      results[0].cast<LocalCardDeckRow>(),
      results[1].cast<LocalStudyCardRow>(),
    );
  }

  @override
  Future<CardDeck?> getDeck(int deckId) async {
    final row = await _deckQuery(deckId).getSingleOrNull();
    return row == null ? null : mapper.deckFromRow(row);
  }

  @override
  Future<StudyCard?> getCard(int cardId) async {
    final row = await _cardQuery(cardId).getSingleOrNull();
    if (row == null) return null;
    final deckRow = await _deckQuery(row.deckId).getSingleOrNull();
    return mapper.cardFromRow(
      row,
      deckRow == null ? null : mapper.deckFromRow(deckRow),
    );
  }

  @override
  Future<List<StudyCard>> cardsForDeck(int deckId) async {
    final deck = await getDeck(deckId);
    if (deck == null) return const <StudyCard>[];
    final rows =
        await (database.select(database.localStudyCards)..where(
              (table) =>
                  table.accountKey.equals(_accountKey) &
                  table.deckId.equals(deckId) &
                  table.deletedLocally.equals(false),
            ))
            .get();
    return <StudyCard>[for (final row in rows) mapper.cardFromRow(row, deck)];
  }

  @override
  Future<List<CardDeckManifestEntry>> deckManifest({Set<int>? deckIds}) async {
    final query = database.select(database.localCardDecks)
      ..where(
        (table) =>
            table.accountKey.equals(_accountKey) &
            (deckIds == null
                ? const Constant<bool>(true)
                : table.remoteId.isIn(deckIds)),
      )
      ..orderBy(<OrderingTerm Function(LocalCardDecks)>[
        (table) => OrderingTerm.asc(table.remoteId),
      ]);
    final rows = await query.get();
    return <CardDeckManifestEntry>[
      for (final row in rows)
        CardDeckManifestEntry(deckId: row.remoteId, serverHash: row.serverHash),
    ];
  }

  @override
  Future<void> applySyncBundle(CardDeckSyncBundle bundle) {
    return database.transaction(() => _applySyncBundle(bundle));
  }

  @override
  Future<void> applyCardSnapshot(List<StudyCard> cards) {
    return database.transaction(() => _applyCardSnapshot(cards));
  }

  Future<void> _applyCardSnapshot(List<StudyCard> cards) async {
    final remoteIds = <int>{for (final card in cards) card.id};
    for (final card in cards) {
      if (await _hasPendingCard(card.id)) continue;
      await database
          .into(database.localStudyCards)
          .insertOnConflictUpdate(
            mapper.cardToCompanion(
              card,
              accountKey: _accountKey,
              syncState: CardLocalSyncState.synced,
            ),
          );
    }
    final existing = await (database.select(
      database.localStudyCards,
    )..where((table) => table.accountKey.equals(_accountKey))).get();
    for (final row in existing) {
      if (remoteIds.contains(row.remoteId) ||
          await _hasPendingCard(row.remoteId)) {
        continue;
      }
      await _deleteCard(row.remoteId);
    }
  }

  Future<void> _applySyncBundle(CardDeckSyncBundle bundle) async {
    for (final remote in bundle.decks) {
      await database
          .into(database.localCardDecks)
          .insertOnConflictUpdate(
            mapper.deckToCompanion(
              remote.deck,
              accountKey: _accountKey,
              serverHash: remote.serverHash,
            ),
          );
      final remoteIds = <int>{for (final card in remote.cards) card.id};
      for (final card in remote.cards) {
        if (await _hasPendingCard(card.id)) continue;
        await database
            .into(database.localStudyCards)
            .insertOnConflictUpdate(
              mapper.cardToCompanion(
                card,
                accountKey: _accountKey,
                syncState: CardLocalSyncState.synced,
              ),
            );
      }
      final existing =
          await (database.select(database.localStudyCards)..where(
                (table) =>
                    table.accountKey.equals(_accountKey) &
                    table.deckId.equals(remote.deck.id),
              ))
              .get();
      for (final row in existing) {
        if (remoteIds.contains(row.remoteId) ||
            await _hasPendingCard(row.remoteId)) {
          continue;
        }
        await _deleteCard(row.remoteId);
      }
    }

    for (final deckId in bundle.deletedDeckIds) {
      final cards =
          await (database.select(database.localStudyCards)..where(
                (table) =>
                    table.accountKey.equals(_accountKey) &
                    table.deckId.equals(deckId),
              ))
              .get();
      for (final card in cards) {
        await _outbox.deleteForRemote(
          collection: 'cards',
          remoteId: card.remoteId,
        );
      }
      await (database.delete(database.localStudyCards)..where(
            (table) =>
                table.accountKey.equals(_accountKey) &
                table.deckId.equals(deckId),
          ))
          .go();
      await _deleteDeck(deckId);
    }
  }

  @override
  Future<void> saveCardAndEnqueue(
    StudyCard card, {
    required String operationId,
    required MutationType mutationType,
    required DateTime createdAt,
  }) async {
    if (mutationType != MutationType.update &&
        mutationType != MutationType.delete) {
      throw ArgumentError('Cards currently enqueue only update or delete');
    }
    await database.transaction(() async {
      await database
          .into(database.localStudyCards)
          .insertOnConflictUpdate(
            mapper.cardToCompanion(
              card,
              accountKey: _accountKey,
              syncState: CardLocalSyncState.queued,
              deletedLocally: mutationType == MutationType.delete,
            ),
          );
      await _outbox.enqueueReplacing(
        PendingMutation(
          operationId: operationId,
          account: account,
          collection: 'cards',
          entityKey: EntityKey(localId: 'card:${card.id}', remoteId: card.id),
          type: mutationType,
          payload: <String, Object?>{
            'client_updated_at': createdAt.toUtc().toIso8601String(),
          },
          createdAt: createdAt.toUtc(),
        ),
      );
    });
  }

  @override
  Future<List<PendingMutation>> pendingMutations() =>
      _outbox.pendingMutations();

  @override
  Future<PendingMutation?> claimNext({
    required String workerId,
    required DateTime now,
    required Duration lease,
  }) => _outbox.claimNext(workerId: workerId, now: now, lease: lease);

  @override
  Future<void> complete(MutationReceipt receipt) {
    return database.transaction(() async {
      final operation = await _outbox.operation(receipt.operationId);
      if (operation == null) return;
      await _outbox.deleteOperation(receipt.operationId);

      final bundle = receipt.metadata[cardSyncBundleMetadataKey];
      if (bundle is CardDeckSyncBundle) await _applySyncBundle(bundle);
      final snapshot = receipt.metadata[cardSnapshotMetadataKey];
      if (snapshot is List<StudyCard>) await _applyCardSnapshot(snapshot);

      final remoteId = operation.entityKey.remoteId;
      if (remoteId == null) return;
      if (operation.type == MutationType.delete) {
        final status = receipt.metadata[cardMutationStatusMetadataKey];
        // A stale delete was rejected by the server. The canonical bundle
        // applied above is authoritative, so keep the restored server card.
        if (status != CardMutationStatus.stale.name) {
          await _deleteCard(remoteId);
        }
        return;
      }
      await (database.update(database.localStudyCards)..where(
            (table) =>
                table.accountKey.equals(_accountKey) &
                table.remoteId.equals(remoteId),
          ))
          .write(
            LocalStudyCardsCompanion(
              syncState: Value(CardLocalSyncState.synced.name),
              deletedLocally: const Value(false),
            ),
          );
    });
  }

  @override
  Future<void> fail(
    String operationId, {
    required SyncFailure failure,
    required DateTime retryAt,
  }) {
    return database.transaction(() async {
      final operation = await _outbox.operation(operationId);
      if (operation == null) return;
      await _outbox.fail(operationId, failure: failure, retryAt: retryAt);
      if (operation.entityKey.remoteId case final remoteId?) {
        await (database.update(database.localStudyCards)..where(
              (table) =>
                  table.accountKey.equals(_accountKey) &
                  table.remoteId.equals(remoteId),
            ))
            .write(
              LocalStudyCardsCompanion(
                syncState: Value(
                  failure.isRetryable
                      ? CardLocalSyncState.retryWaiting.name
                      : CardLocalSyncState.blocked.name,
                ),
              ),
            );
      }
    });
  }

  @override
  Future<DateTime?> nextRetryAt() => _outbox.nextRetryAt();

  CardsDashboard _dashboard(
    List<LocalCardDeckRow> deckRows,
    List<LocalStudyCardRow> cardRows,
  ) {
    final decks = <CardDeck>[
      for (final row in deckRows) mapper.deckFromRow(row),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final deckById = <int, CardDeck>{for (final deck in decks) deck.id: deck};
    final cards = <StudyCard>[
      for (final row in cardRows) mapper.cardFromRow(row, deckById[row.deckId]),
    ];
    return CardsDashboard(decks: decks, cards: cards);
  }

  Future<bool> _hasPendingCard(int cardId) =>
      _outbox.hasPendingRemote(collection: 'cards', remoteId: cardId);

  SimpleSelectStatement<$LocalCardDecksTable, LocalCardDeckRow> _deckQuery(
    int deckId,
  ) => database.select(database.localCardDecks)
    ..where(
      (table) =>
          table.accountKey.equals(_accountKey) & table.remoteId.equals(deckId),
    );

  SimpleSelectStatement<$LocalStudyCardsTable, LocalStudyCardRow> _cardQuery(
    int cardId,
  ) => database.select(database.localStudyCards)
    ..where(
      (table) =>
          table.accountKey.equals(_accountKey) & table.remoteId.equals(cardId),
    );

  Future<int> _deleteCard(int cardId) =>
      (database.delete(database.localStudyCards)..where(
            (table) =>
                table.accountKey.equals(_accountKey) &
                table.remoteId.equals(cardId),
          ))
          .go();

  Future<int> _deleteDeck(int deckId) =>
      (database.delete(database.localCardDecks)..where(
            (table) =>
                table.accountKey.equals(_accountKey) &
                table.remoteId.equals(deckId),
          ))
          .go();
}
