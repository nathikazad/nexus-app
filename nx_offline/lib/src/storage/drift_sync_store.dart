import 'dart:convert';

import 'package:drift/drift.dart';

import '../core/sync_models.dart';
import '../sync/policies.dart';
import '../sync/sync_ports.dart';
import 'sync_database.dart';

final class DriftSyncStore implements SyncStore {
  DriftSyncStore({
    required this.database,
    required this.account,
    this.coalescer = const OutboxCoalescer(),
  });

  final SyncDatabase database;

  @override
  final AccountScope account;

  final OutboxCoalescer coalescer;

  Stream<List<LocalEntity>> watchEntities(
    String collection, {
    bool includeDeleted = false,
  }) {
    final query = database.select(database.localEntities)
      ..where(
        (table) =>
            table.accountKey.equals(account.key) &
            table.collection.equals(collection) &
            (includeDeleted
                ? const Constant(true)
                : table.deleted.equals(false)),
      )
      ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]);
    return query.watch().map(
      (rows) => rows.map(_entityFromRow).toList(growable: false),
    );
  }

  Future<LocalEntity?> getEntity(String collection, EntityKey key) async {
    final row = await _entityQuery(collection, key.localId).getSingleOrNull();
    return row == null ? null : _entityFromRow(row);
  }

  Future<void> saveEntityAndEnqueue(
    LocalEntity entity,
    PendingMutation mutation,
  ) async {
    _validate(entity, mutation);
    await database.transaction(() async {
      final existingRow = await _outboxFor(
        entity.collection,
        entity.key.localId,
      ).getSingleOrNull();
      final existing = existingRow == null
          ? null
          : _mutationFromRow(existingRow);
      final next = existing == null
          ? mutation
          : coalescer.coalesce(existing, mutation);
      final saved = entity.copyWith(
        syncState: next == null
            ? EntitySyncState.synced
            : EntitySyncState.queued,
      );
      await database
          .into(database.localEntities)
          .insertOnConflictUpdate(_entityCompanion(saved));
      if (existingRow != null) {
        await (database.delete(database.syncOutbox)..where(
              (table) => table.operationId.equals(existingRow.operationId),
            ))
            .go();
      }
      if (next != null) {
        await database
            .into(database.syncOutbox)
            .insertOnConflictUpdate(_mutationCompanion(next));
      }
    });
  }

  Future<bool> importRemote(RemoteRecord record, DateTime now) async {
    if (record.collection.isEmpty) {
      throw ArgumentError.value(record.collection, 'record.collection');
    }
    return database.transaction(() async {
      final row = await _entityQuery(
        record.collection,
        record.entityKey.localId,
      ).getSingleOrNull();
      final pending = await _outboxFor(
        record.collection,
        record.entityKey.localId,
      ).getSingleOrNull();
      if (row != null && pending != null) return false;
      final entity = LocalEntity(
        account: account,
        collection: record.collection,
        key: record.entityKey,
        payload: record.payload,
        updatedAt: now,
        syncState: EntitySyncState.synced,
        revision: record.revision,
        baseRevision: record.revision,
      );
      await database
          .into(database.localEntities)
          .insertOnConflictUpdate(_entityCompanion(entity));
      return true;
    });
  }

  Future<bool> importTombstone(RemoteTombstone tombstone, DateTime now) async {
    return database.transaction(() async {
      final pending = await _outboxFor(
        tombstone.collection,
        tombstone.entityKey.localId,
      ).getSingleOrNull();
      if (pending != null) return false;
      final query = _entityQuery(
        tombstone.collection,
        tombstone.entityKey.localId,
      );
      final row = await query.getSingleOrNull();
      if (row == null) return true;
      await (database.update(database.localEntities)..where(
            (table) =>
                table.accountKey.equals(account.key) &
                table.collection.equals(tombstone.collection) &
                table.localId.equals(tombstone.entityKey.localId),
          ))
          .write(
            LocalEntitiesCompanion(
              deleted: const Value(true),
              updatedAt: Value(now),
              revision: Value(tombstone.revision.value),
              baseRevision: Value(tombstone.revision.value),
              syncState: Value(EntitySyncState.synced.name),
            ),
          );
      return true;
    });
  }

  @override
  Future<void> enqueue(PendingMutation mutation) async {
    if (mutation.account != account) throw StateError('account mismatch');
    final entity = await getEntity(mutation.collection, mutation.entityKey);
    if (entity == null) {
      throw StateError('enqueue requires an existing local entity');
    }
    await saveEntityAndEnqueue(entity, mutation);
  }

  @override
  Future<List<PendingMutation>> pendingMutations() async {
    final rows =
        await (database.select(database.syncOutbox)
              ..where((table) => table.accountKey.equals(account.key))
              ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]))
            .get();
    return rows.map(_mutationFromRow).toList(growable: false);
  }

  @override
  Future<PendingMutation?> claimNext({
    required String workerId,
    required DateTime now,
    required Duration lease,
  }) {
    if (lease <= Duration.zero) {
      throw ArgumentError.value(lease, 'lease', 'must be positive');
    }
    return database.transaction(() async {
      final rows = await pendingMutations();
      for (final mutation in rows) {
        if (!mutation.isEligibleAt(now)) continue;
        final claimed = mutation.copyWith(
          status: PendingMutationStatus.claimed,
          leaseOwner: workerId,
          leaseExpiresAt: now.add(lease),
          clearNextAttemptAt: true,
        );
        await (database.update(
              database.syncOutbox,
            )..where((table) => table.operationId.equals(mutation.operationId)))
            .write(_mutationCompanion(claimed));
        await _setEntityState(
          mutation.collection,
          mutation.entityKey.localId,
          EntitySyncState.syncing,
        );
        return claimed;
      }
      return null;
    });
  }

  @override
  Future<void> complete(MutationReceipt receipt) {
    return database.transaction(() async {
      final row =
          await (database.select(database.syncOutbox)..where(
                (table) => table.operationId.equals(receipt.operationId),
              ))
              .getSingleOrNull();
      if (row == null || row.accountKey != account.key) {
        throw StateError('pending mutation not found: ${receipt.operationId}');
      }
      await (database.update(database.localEntities)..where(
            (table) =>
                table.accountKey.equals(account.key) &
                table.collection.equals(row.collection) &
                table.localId.equals(row.localId),
          ))
          .write(
            LocalEntitiesCompanion(
              remoteId: Value(receipt.entityKey.remoteId),
              revision: Value(receipt.revision.value),
              baseRevision: Value(receipt.revision.value),
              syncState: Value(EntitySyncState.synced.name),
            ),
          );
      await (database.delete(
        database.syncOutbox,
      )..where((table) => table.operationId.equals(receipt.operationId))).go();
    });
  }

  @override
  Future<void> fail(
    String operationId, {
    required SyncFailure failure,
    required DateTime retryAt,
  }) {
    return database.transaction(() async {
      final row =
          await (database.select(database.syncOutbox)
                ..where((table) => table.operationId.equals(operationId)))
              .getSingleOrNull();
      if (row == null || row.accountKey != account.key) {
        throw StateError('pending mutation not found: $operationId');
      }
      final mutation = _mutationFromRow(row);
      final failed = mutation.copyWith(
        status: PendingMutationStatus.retryWaiting,
        attemptCount: mutation.attemptCount + 1,
        nextAttemptAt: retryAt,
        lastError: failure.message,
        clearLease: true,
      );
      await (database.update(database.syncOutbox)
            ..where((table) => table.operationId.equals(operationId)))
          .write(_mutationCompanion(failed));
      await _setEntityState(
        row.collection,
        row.localId,
        failure.kind == SyncFailureKind.conflict
            ? EntitySyncState.conflict
            : EntitySyncState.retryWaiting,
      );
    });
  }

  @override
  Future<SyncCursor?> readCursor(String collection) async {
    final row =
        await (database.select(database.syncCursors)..where(
              (table) =>
                  table.accountKey.equals(account.key) &
                  table.collection.equals(collection),
            ))
            .getSingleOrNull();
    return row == null ? null : SyncCursor(row.cursor);
  }

  @override
  Future<void> writeCursor(String collection, SyncCursor cursor) async {
    await database
        .into(database.syncCursors)
        .insertOnConflictUpdate(
          SyncCursorsCompanion.insert(
            accountKey: account.key,
            collection: collection,
            cursor: cursor.value,
          ),
        );
  }

  @override
  Future<void> recordConflict(SyncConflict conflict) {
    if (conflict.account != account) throw StateError('account mismatch');
    return database.transaction(() async {
      await database
          .into(database.syncConflicts)
          .insertOnConflictUpdate(
            SyncConflictsCompanion.insert(
              accountKey: account.key,
              collection: conflict.collection,
              localId: conflict.entityKey.localId,
              remoteId: Value(conflict.entityKey.remoteId),
              localPayloadJson: jsonEncode(conflict.localPayload),
              remotePayloadJson: jsonEncode(conflict.remotePayload),
              remoteRevision: conflict.remoteRevision.value,
              detectedAt: conflict.detectedAt,
            ),
          );
      await _setEntityState(
        conflict.collection,
        conflict.entityKey.localId,
        EntitySyncState.conflict,
      );
    });
  }

  SimpleSelectStatement<$LocalEntitiesTable, LocalEntityRow> _entityQuery(
    String collection,
    String localId,
  ) {
    return database.select(database.localEntities)..where(
      (table) =>
          table.accountKey.equals(account.key) &
          table.collection.equals(collection) &
          table.localId.equals(localId),
    );
  }

  SimpleSelectStatement<$SyncOutboxTable, SyncOutboxData> _outboxFor(
    String collection,
    String localId,
  ) {
    return database.select(database.syncOutbox)..where(
      (table) =>
          table.accountKey.equals(account.key) &
          table.collection.equals(collection) &
          table.localId.equals(localId),
    );
  }

  Future<void> _setEntityState(
    String collection,
    String localId,
    EntitySyncState state,
  ) async {
    await (database.update(database.localEntities)..where(
          (table) =>
              table.accountKey.equals(account.key) &
              table.collection.equals(collection) &
              table.localId.equals(localId),
        ))
        .write(LocalEntitiesCompanion(syncState: Value(state.name)));
  }

  LocalEntity _entityFromRow(LocalEntityRow row) {
    return LocalEntity(
      account: account,
      collection: row.collection,
      key: EntityKey(localId: row.localId, remoteId: row.remoteId),
      payload: _decode(row.payloadJson),
      updatedAt: row.updatedAt,
      syncState: EntitySyncState.values.byName(row.syncState),
      revision: row.revision == null ? null : Revision(row.revision!),
      baseRevision: row.baseRevision == null
          ? null
          : Revision(row.baseRevision!),
      deleted: row.deleted,
    );
  }

  LocalEntitiesCompanion _entityCompanion(LocalEntity entity) {
    return LocalEntitiesCompanion.insert(
      accountKey: account.key,
      collection: entity.collection,
      localId: entity.key.localId,
      remoteId: Value(entity.key.remoteId),
      payloadJson: jsonEncode(entity.payload),
      updatedAt: entity.updatedAt,
      revision: Value(entity.revision?.value),
      baseRevision: Value(entity.baseRevision?.value),
      syncState: entity.syncState.name,
      deleted: Value(entity.deleted),
    );
  }

  PendingMutation _mutationFromRow(SyncOutboxData row) {
    return PendingMutation(
      operationId: row.operationId,
      account: account,
      collection: row.collection,
      entityKey: EntityKey(localId: row.localId, remoteId: row.remoteId),
      type: MutationType.values.byName(row.mutationType),
      payload: _decode(row.payloadJson),
      baseRevision: row.baseRevision == null
          ? null
          : Revision(row.baseRevision!),
      createdAt: row.createdAt,
      status: PendingMutationStatus.values.byName(row.status),
      attemptCount: row.attemptCount,
      nextAttemptAt: row.nextAttemptAt,
      leaseOwner: row.leaseOwner,
      leaseExpiresAt: row.leaseExpiresAt,
      lastError: row.lastError,
      operationGroup: row.operationGroup,
    );
  }

  SyncOutboxCompanion _mutationCompanion(PendingMutation mutation) {
    return SyncOutboxCompanion.insert(
      operationId: mutation.operationId,
      accountKey: account.key,
      collection: mutation.collection,
      localId: mutation.entityKey.localId,
      remoteId: Value(mutation.entityKey.remoteId),
      mutationType: mutation.type.name,
      payloadJson: jsonEncode(mutation.payload),
      baseRevision: Value(mutation.baseRevision?.value),
      status: mutation.status.name,
      attemptCount: Value(mutation.attemptCount),
      nextAttemptAt: Value(mutation.nextAttemptAt),
      leaseOwner: Value(mutation.leaseOwner),
      leaseExpiresAt: Value(mutation.leaseExpiresAt),
      lastError: Value(mutation.lastError),
      operationGroup: Value(mutation.operationGroup),
      createdAt: mutation.createdAt,
    );
  }

  void _validate(LocalEntity entity, PendingMutation mutation) {
    if (entity.account != account || mutation.account != account) {
      throw StateError('account mismatch');
    }
    if (entity.collection != mutation.collection ||
        entity.key != mutation.entityKey) {
      throw StateError('entity and mutation targets do not match');
    }
  }

  Map<String, Object?> _decode(String source) {
    return Map<String, Object?>.from(jsonDecode(source) as Map);
  }
}
