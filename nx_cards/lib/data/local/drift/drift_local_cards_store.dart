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
    final cardStream =
        (database.select(database.localStudyCards)..where(
              (table) =>
                  table.accountKey.equals(_accountKey) &
                  table.deletedLocally.equals(false),
            ))
            .watch();
    return cardStream.map(_dashboard);
  }

  @override
  Future<CardsDashboard> readDashboard() async {
    final rows =
        await (database.select(database.localStudyCards)..where(
              (table) =>
                  table.accountKey.equals(_accountKey) &
                  table.deletedLocally.equals(false),
            ))
            .get();
    return _dashboard(rows);
  }

  @override
  Future<StudyCard?> getCard(int cardId) async {
    final row = await _cardQuery(cardId).getSingleOrNull();
    if (row == null) return null;
    return mapper.cardFromRow(row);
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

  CardsDashboard _dashboard(List<LocalStudyCardRow> cardRows) {
    final cards = <StudyCard>[
      for (final row in cardRows) mapper.cardFromRow(row),
    ];
    return CardsDashboard(cards: cards);
  }

  Future<bool> _hasPendingCard(int cardId) =>
      _outbox.hasPendingRemote(collection: 'cards', remoteId: cardId);

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
}
