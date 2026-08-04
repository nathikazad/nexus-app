import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/sync_models.dart';

/// Shared raw-SQL persistence for an application's embedded outbox tables.
///
/// Drift cannot generate table classes from Dart declarations located in a
/// dependency package. Keeping the shared tables behind this small DAO lets
/// every application embed the exact same schema in its own physical database
/// while its typed domain writes and outbox writes still share a transaction.
final class DriftOutboxPersistence {
  const DriftOutboxPersistence({required this.database, required this.account});

  final GeneratedDatabase database;
  final AccountIdentity account;

  static Future<void> createSchema(GeneratedDatabase database) async {
    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS offline_outbox (
        operation_id TEXT NOT NULL PRIMARY KEY,
        account_key TEXT NOT NULL,
        collection TEXT NOT NULL,
        aggregate_id TEXT NOT NULL,
        remote_id INTEGER NULL,
        operation_type TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        base_revision TEXT NULL,
        status TEXT NOT NULL,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        next_attempt_at TEXT NULL,
        lease_owner TEXT NULL,
        lease_expires_at TEXT NULL,
        last_error TEXT NULL,
        operation_group TEXT NULL,
        created_at TEXT NOT NULL,
        UNIQUE (account_key, collection, aggregate_id)
      )
    ''');
    await database.customStatement('''
      CREATE INDEX IF NOT EXISTS offline_outbox_account_created
      ON offline_outbox (account_key, created_at)
    ''');
    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS offline_sync_metadata (
        account_key TEXT NOT NULL,
        dataset TEXT NOT NULL,
        cursor TEXT NULL,
        last_completed_at TEXT NULL,
        PRIMARY KEY (account_key, dataset)
      )
    ''');
    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS offline_conflicts (
        account_key TEXT NOT NULL,
        collection TEXT NOT NULL,
        aggregate_id TEXT NOT NULL,
        remote_id INTEGER NULL,
        local_payload_json TEXT NOT NULL,
        remote_payload_json TEXT NOT NULL,
        remote_revision TEXT NOT NULL,
        detected_at TEXT NOT NULL,
        PRIMARY KEY (account_key, collection, aggregate_id)
      )
    ''');
  }

  Future<void> enqueueReplacing(PendingMutation mutation) async {
    _checkAccount(mutation);
    await database.customStatement(
      '''
      DELETE FROM offline_outbox
      WHERE account_key = ? AND collection = ? AND aggregate_id = ?
      ''',
      <Object?>[account.key, mutation.collection, mutation.entityKey.localId],
    );
    await database.customStatement(
      '''
      INSERT INTO offline_outbox (
        operation_id, account_key, collection, aggregate_id, remote_id,
        operation_type, payload_json, base_revision, status, attempt_count,
        next_attempt_at, lease_owner, lease_expires_at, last_error,
        operation_group, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      <Object?>[
        mutation.operationId,
        account.key,
        mutation.collection,
        mutation.entityKey.localId,
        mutation.entityKey.remoteId,
        mutation.type.name,
        jsonEncode(mutation.payload),
        mutation.baseRevision?.value,
        mutation.status.name,
        mutation.attemptCount,
        _timestamp(mutation.nextAttemptAt),
        mutation.leaseOwner,
        _timestamp(mutation.leaseExpiresAt),
        mutation.lastError,
        mutation.operationGroup,
        _timestamp(mutation.createdAt)!,
      ],
    );
  }

  Future<List<PendingMutation>> pendingMutations() async {
    final rows = await database
        .customSelect(
          '''
          SELECT * FROM offline_outbox
          WHERE account_key = ?
          ORDER BY created_at, operation_id
          ''',
          variables: <Variable<Object>>[Variable<String>(account.key)],
        )
        .get();
    return <PendingMutation>[for (final row in rows) _mutation(row.data)];
  }

  Future<PendingMutation?> operation(String operationId) async {
    final row = await database
        .customSelect(
          '''
          SELECT * FROM offline_outbox
          WHERE account_key = ? AND operation_id = ?
          LIMIT 1
          ''',
          variables: <Variable<Object>>[
            Variable<String>(account.key),
            Variable<String>(operationId),
          ],
        )
        .getSingleOrNull();
    return row == null ? null : _mutation(row.data);
  }

  Future<PendingMutation?> claimNext({
    required String workerId,
    required DateTime now,
    required Duration lease,
  }) {
    return database.transaction(() async {
      for (final mutation in await pendingMutations()) {
        if (!mutation.isEligibleAt(now)) continue;
        final claimed = mutation.copyWith(
          status: PendingMutationStatus.claimed,
          leaseOwner: workerId,
          leaseExpiresAt: now.add(lease),
          clearNextAttemptAt: true,
        );
        await database.customStatement(
          '''
          UPDATE offline_outbox
          SET status = ?, next_attempt_at = NULL,
              lease_owner = ?, lease_expires_at = ?
          WHERE account_key = ? AND operation_id = ?
          ''',
          <Object?>[
            claimed.status.name,
            workerId,
            _timestamp(claimed.leaseExpiresAt),
            account.key,
            claimed.operationId,
          ],
        );
        return claimed;
      }
      return null;
    });
  }

  Future<void> deleteOperation(String operationId) {
    return database.customStatement(
      '''
      DELETE FROM offline_outbox
      WHERE account_key = ? AND operation_id = ?
      ''',
      <Object?>[account.key, operationId],
    );
  }

  Future<void> deleteForRemote({
    required String collection,
    required int remoteId,
  }) {
    return database.customStatement(
      '''
      DELETE FROM offline_outbox
      WHERE account_key = ? AND collection = ? AND remote_id = ?
      ''',
      <Object?>[account.key, collection, remoteId],
    );
  }

  Future<bool> hasPendingRemote({
    required String collection,
    required int remoteId,
  }) async {
    final row = await database
        .customSelect(
          '''
          SELECT 1 AS found FROM offline_outbox
          WHERE account_key = ? AND collection = ? AND remote_id = ?
          LIMIT 1
          ''',
          variables: <Variable<Object>>[
            Variable<String>(account.key),
            Variable<String>(collection),
            Variable<int>(remoteId),
          ],
        )
        .getSingleOrNull();
    return row != null;
  }

  Future<void> fail(
    String operationId, {
    required SyncFailure failure,
    required DateTime retryAt,
  }) {
    return database.customStatement(
      '''
      UPDATE offline_outbox
      SET status = ?, attempt_count = attempt_count + 1,
          next_attempt_at = ?, lease_owner = NULL, lease_expires_at = NULL,
          last_error = ?
      WHERE account_key = ? AND operation_id = ?
      ''',
      <Object?>[
        failure.isRetryable
            ? PendingMutationStatus.retryWaiting.name
            : PendingMutationStatus.blocked.name,
        _timestamp(retryAt),
        failure.message,
        account.key,
        operationId,
      ],
    );
  }

  Future<DateTime?> nextRetryAt() async {
    final row = await database
        .customSelect(
          '''
          SELECT MIN(next_attempt_at) AS retry_at
          FROM offline_outbox
          WHERE account_key = ? AND status = ?
          ''',
          variables: <Variable<Object>>[
            Variable<String>(account.key),
            Variable<String>(PendingMutationStatus.retryWaiting.name),
          ],
        )
        .getSingle();
    return _parseTimestamp(row.data['retry_at']);
  }

  PendingMutation _mutation(Map<String, Object?> row) {
    final payload = jsonDecode(row['payload_json']! as String);
    final remoteId = row['remote_id'];
    return PendingMutation(
      operationId: row['operation_id']! as String,
      account: account,
      collection: row['collection']! as String,
      entityKey: EntityKey(
        localId: row['aggregate_id']! as String,
        remoteId: remoteId is int ? remoteId : null,
      ),
      type: MutationType.values.byName(row['operation_type']! as String),
      payload: payload is Map
          ? Map<String, Object?>.from(payload)
          : const <String, Object?>{},
      baseRevision: switch (row['base_revision']) {
        final String value when value.isNotEmpty => Revision(value),
        _ => null,
      },
      status: PendingMutationStatus.values.byName(row['status']! as String),
      attemptCount: row['attempt_count']! as int,
      nextAttemptAt: _parseTimestamp(row['next_attempt_at']),
      leaseOwner: row['lease_owner'] as String?,
      leaseExpiresAt: _parseTimestamp(row['lease_expires_at']),
      lastError: row['last_error'] as String?,
      operationGroup: row['operation_group'] as String?,
      createdAt: _parseTimestamp(row['created_at'])!,
    );
  }

  void _checkAccount(PendingMutation mutation) {
    if (mutation.account != account) {
      throw StateError('Outbox mutation belongs to a different account');
    }
  }

  static String? _timestamp(DateTime? value) =>
      value?.toUtc().toIso8601String();

  static DateTime? _parseTimestamp(Object? value) =>
      DateTime.tryParse(value?.toString() ?? '')?.toUtc();
}
