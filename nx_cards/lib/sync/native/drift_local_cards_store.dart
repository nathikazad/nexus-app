import 'package:flutter/foundation.dart';
import '../remote/cards_sync_transport.dart';
import 'dart:async';
import 'dart:convert';
import 'package:nx_offline/nx_offline_storage.dart';

import 'package:drift/drift.dart';
import 'package:nx_cards/sync/native/card_outbox.dart';
import 'package:nx_cards/sync/native/local_cards_store.dart';
import 'package:nx_cards/sync/native/cards_database.dart';
import 'package:nx_cards/sync/native/drift_cards_mapper.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:nx_offline/nx_offline_drift.dart';

final class DriftLocalCardsStore
    implements LocalCardsStore, QueuedCardReader, HashCardsStore {
  DriftLocalCardsStore({
    required this.database,
    required this.account,
    this.files,
    this.mapper = const DriftCardsMapper(),
  });

  final CardsDatabase database;
  final ContentFiles? files;
  Future<void>? _migration;
  @override
  int get editGeneration => _editGeneration;
  int _editGeneration = 0;

  Future<LocalStudyCardsCompanion> _cardToCompanion(
    StudyCard card, {
    required String accountKey,
    required CardLocalSyncState syncState,
    bool deletedLocally = false,
  }) async {
    final row = mapper.cardToCompanion(
      card,
      accountKey: accountKey,
      syncState: syncState,
      deletedLocally: deletedLocally,
    );
    final storage = files;
    if (storage == null) return row;
    final body = jsonEncode({
      'front': row.front.value,
      'back': row.back.value,
      'examples': row.examplesJson.value,
      'history': row.reviewHistoryJson.value,
      'schedule': row.scheduleJson.value,
      'tags': row.tagsJson.value,
      'linked': row.linkedWordIdsJson.value,
      'suspended': row.suspended.value,
      'learning_status': row.learningStatus.value,
      'updated_at': row.updatedAt.value?.toUtc().toIso8601String(),
      'model_type': row.modelType.value,
      'transliteration': row.transliteration.value,
      'audio_url': row.audioUrl.value,
      'source_book_id': row.sourceBookId.value,
      'source_book_name': row.sourceBookName.value,
    });
    final reference = await storage.write('cards', '${card.id}', body);
    return row.copyWith(
      contentRef: Value(reference),
      front: Value(
        card.front.length > 320 ? card.front.substring(0, 320) : card.front,
      ),
      back: Value(
        card.back.length > 320 ? card.back.substring(0, 320) : card.back,
      ),
      examplesJson: const Value('[]'),
      // The UI supports windows up to ten answers. Keep only that bounded
      // projection per cue; full history remains in the immutable body file.
      reviewHistoryJson: Value(
        jsonEncode({
          'items': [
            for (final cue in StudyCue.values)
              ...((card.reviewHistoryFor(cue).toList()
                    ..sort((a, b) => b.reviewedAt.compareTo(a.reviewedAt)))
                  .take(10)
                  .map((r) => {...r.toJson(), 'cue': cue.storageKey})),
          ],
        }),
      ),
    );
  }

  Future<StudyCard> _cardFromRow(LocalStudyCardRow row) async {
    if (row.contentRef == null) return mapper.cardFromRow(row);
    final json = jsonDecode(await files!.read(row.contentRef!)) as Map;
    return mapper.cardFromRow(
      row.copyWith(
        scheduleJson: json['schedule'] as String? ?? row.scheduleJson,
        tagsJson: json['tags'] as String? ?? row.tagsJson,
        linkedWordIdsJson: json['linked'] as String? ?? row.linkedWordIdsJson,
        suspended: json['suspended'] as bool? ?? row.suspended,
        learningStatus:
            json['learning_status'] as String? ?? row.learningStatus,
        updatedAt: Value(
          json.containsKey('updated_at')
              ? DateTime.tryParse(json['updated_at']?.toString() ?? '')
              : row.updatedAt,
        ),
        modelType: json['model_type'] as String? ?? row.modelType,
        transliteration: Value(json['transliteration'] as String?),
        audioUrl: Value(json['audio_url'] as String?),
        sourceBookId: Value(json['source_book_id'] as int?),
        sourceBookName: Value(json['source_book_name'] as String?),
        front: json['front'] as String,
        back: json['back'] as String,
        examplesJson: json['examples'] as String,
        reviewHistoryJson: json['history'] as String,
      ),
    );
  }

  Future<void> migrateContent() => _migration ??= _migrate();
  Future<void> _migrate() async {
    if (files == null) return;
    while (true) {
      final rows =
          await (database.select(database.localStudyCards)
                ..where(
                  (t) =>
                      t.accountKey.equals(_accountKey) & t.contentRef.isNull(),
                )
                ..limit(25))
              .get();
      if (rows.isEmpty) return;
      for (final row in rows) {
        final next = await _cardToCompanion(
          mapper.cardFromRow(row),
          accountKey: _accountKey,
          syncState: CardLocalSyncState.values.byName(row.syncState),
          deletedLocally: row.deletedLocally,
        );
        await (database.update(database.localStudyCards)..where(
              (t) =>
                  t.accountKey.equals(_accountKey) &
                  t.remoteId.equals(row.remoteId) &
                  t.contentRef.isNull(),
            ))
            .write(next);
      }
    }
  }

  @override
  final AccountIdentity account;
  final DriftCardsMapper mapper;

  String get _accountKey => account.key;
  DriftOutboxPersistence get _outbox =>
      DriftOutboxPersistence(database: database, account: account);

  @override
  Stream<CardsDashboard> watchDashboard() async* {
    await migrateContent();
    final cardStream =
        (database.select(database.localStudyCards)..where(
              (table) =>
                  table.accountKey.equals(_accountKey) &
                  table.deletedLocally.equals(false),
            ))
            .watch();
    yield* cardStream.asyncMap(_dashboard);
  }

  @override
  Future<CardsDashboard> readDashboard() async {
    await migrateContent();
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
    final clock = Stopwatch()..start();
    final row = await _cardQuery(cardId).getSingleOrNull();
    final queryMs = clock.elapsedMilliseconds;
    if (row == null) return null;
    final card = await _cardFromRow(row);
    debugPrint(
      'NxCardsStartup stage=card_read query_ms=$queryMs body_ms=${clock.elapsedMilliseconds - queryMs} total_ms=${clock.elapsedMilliseconds}',
    );
    return card;
  }

  @override
  Future<StudyCard?> readQueuedCard(int cardId, String reference) async {
    final row = await _cardQuery(cardId).getSingleOrNull();
    return row == null
        ? null
        : _cardFromRow(row.copyWith(contentRef: Value(reference)));
  }

  @override
  Future<bool> verifiedCard(CardHash entry) async {
    final rows = await database
        .customSelect(
          'SELECT h.hash, c.content_ref FROM card_sync_hashes h '
          'JOIN local_study_cards c ON c.account_key = h.account_key AND c.remote_id = h.card_id '
          'WHERE h.account_key = ? AND h.card_id = ? AND h.content_ref IS c.content_ref',
          variables: [Variable(_accountKey), Variable(entry.id)],
        )
        .get();
    if (rows.isEmpty || rows.single.read<String>('hash') != entry.hash) {
      return false;
    }
    final ref = rows.single.readNullable<String>('content_ref');
    return ref == null ? files == null : await files?.exists(ref) == true;
  }

  Future<void> _clearHash(int id) => database.customStatement(
    'DELETE FROM card_sync_hashes WHERE account_key = ? AND card_id = ?',
    [_accountKey, id],
  );

  @override
  Future<List<int>> applyCardBatch(
    List<HashedCard> cards, {
    int? expectedGeneration,
  }) async {
    await database.transaction(() async {
      if (expectedGeneration != null && expectedGeneration != editGeneration) {
        return;
      }
      for (final entry in cards) {
        // Never certify a server hash for a locally edited body.
        if (await _hasPendingCard(entry.card.id)) continue;
        final row = await _cardToCompanion(
          entry.card,
          accountKey: _accountKey,
          syncState: CardLocalSyncState.synced,
        );
        await database
            .into(database.localStudyCards)
            .insertOnConflictUpdate(row);
        await database.customStatement(
          'INSERT OR REPLACE INTO card_sync_hashes(account_key, card_id, hash, content_ref) VALUES (?, ?, ?, ?)',
          [_accountKey, entry.card.id, entry.hash, row.contentRef.value],
        );
      }
    });
    return [];
  }

  @override
  Future<void> publishCardManifest(
    List<CardHash> manifest, {
    int? expectedGeneration,
  }) async {
    if (expectedGeneration != null && expectedGeneration != editGeneration) {
      return;
    }
    final ids = manifest.map((entry) => entry.id).toSet();
    await database.transaction(() async {
      final rows = await (database.select(
        database.localStudyCards,
      )..where((t) => t.accountKey.equals(_accountKey))).get();
      for (final row in rows) {
        if (!ids.contains(row.remoteId) &&
            !await _hasPendingCard(row.remoteId)) {
          await _clearHash(row.remoteId);
          await _deleteCard(row.remoteId);
        }
      }
    });
  }

  @override
  Future<void> applyCardSnapshot(List<StudyCard> cards) {
    return database.transaction(() => _applyCardSnapshot(cards));
  }

  Future<void> _applyCardSnapshot(List<StudyCard> cards) async {
    final remoteIds = <int>{for (final card in cards) card.id};
    for (final card in cards) {
      if (await _hasPendingCard(card.id)) continue;
      _editGeneration++;
      await _clearHash(card.id);
      await database
          .into(database.localStudyCards)
          .insertOnConflictUpdate(
            await _cardToCompanion(
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
    if (card.isSummary) {
      throw StateError('Cannot save a card projection as full content.');
    }
    if (mutationType != MutationType.update &&
        mutationType != MutationType.delete) {
      throw ArgumentError('Cards currently enqueue only update or delete');
    }
    await database.transaction(() async {
      _editGeneration++;
      await _clearHash(card.id);
      await database
          .into(database.localStudyCards)
          .insertOnConflictUpdate(
            await _cardToCompanion(
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
            if (files != null)
              'body_ref': (await _cardQuery(card.id).getSingle()).contentRef,
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

  Future<CardsDashboard> _dashboard(List<LocalStudyCardRow> cardRows) async {
    final cards = <StudyCard>[
      for (final row in cardRows)
        mapper.cardFromRow(row).copyWith(isSummary: row.contentRef != null),
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
