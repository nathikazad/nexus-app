import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:nx_offline/nx_offline_drift.dart';
import 'package:nx_offline/nx_offline_storage.dart';

/// One native server/user/domain/app partition. Commands and optimistic views
/// share a SQLite transaction; immutable payload files are finalized first.
class ExpenseStore implements OutboxStore {
  ExpenseStore(this.library, this.account)
    : outbox = DriftOutboxPersistence(
        database: library.database,
        account: account,
      );
  final FileLibrary library;
  @override
  final AccountIdentity account;
  final DriftOutboxPersistence outbox;
  final List<Future<void> Function()> beforeClose = [];
  Future<void>? _closing;
  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    for (final stop in beforeClose.reversed) {
      await stop();
    }
    await library.close();
  }

  Future<void>? _ready;
  Future<void> initialize() => _ready ??= _initialize();
  Future<void> _initialize() async {
    await DriftOutboxPersistence.createSchema(library.database);
    await library.database.customStatement(
      '''CREATE TABLE IF NOT EXISTS expense_confirmed (
      local_id TEXT PRIMARY KEY, remote_id INTEGER UNIQUE,
      payload TEXT, revision TEXT, snapshot_hash TEXT)''',
    );
    await library.database.customStatement(
      '''CREATE TABLE IF NOT EXISTS expense_delivery (
      operation_id TEXT PRIMARY KEY, request TEXT NOT NULL)''',
    );
    await library.database.customStatement(
      '''CREATE TABLE IF NOT EXISTS expense_receipts (
      operation_id TEXT PRIMARY KEY, revision TEXT)''',
    );
  }

  Future<Map<String, dynamic>?> get(String id) async {
    await initialize();
    id = await localId(id);
    final metadata = await library.metadata('expense', id);
    if (metadata == null || metadata.deleted) return null;
    return Map<String, dynamic>.from(
      jsonDecode((await library.read('expense', id))!) as Map,
    );
  }

  Future<String> localId(String id) async {
    await initialize();
    final remoteId = int.tryParse(id);
    if (remoteId == null) return id;
    final row = await library.database
        .customSelect(
          'SELECT local_id FROM expense_confirmed WHERE remote_id=?',
          variables: [Variable(remoteId)],
        )
        .getSingleOrNull();
    return row?.read<String>('local_id') ?? id;
  }

  /// Foreground pages are incomplete. They may hydrate rows, never delete rows.
  Future<void> acceptLive(List<Map<String, dynamic>> items) async {
    await initialize();
    await library.batchWrites(() async {
      for (final payload in items) {
        final id = payload['id'] as int;
        final local = await localId('$id');
        await _confirmed(local, id, payload, null);
        await library.saveRemote(
          'expense',
          local,
          jsonEncode(payload),
          revision: payload['revision'] as String?,
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> all() async {
    await initialize();
    final result = <Map<String, dynamic>>[];
    String? after;
    while (true) {
      final rows = await library.list('expense', limit: 200, after: after);
      for (final row in rows) {
        if (!row.deleted) {
          result.add(
            Map<String, dynamic>.from(
              jsonDecode(await library.files.read(row.reference)) as Map,
            ),
          );
        }
      }
      if (rows.length < 200) break;
      after = rows.last.id;
    }
    return result;
  }

  Future<void> enqueue({
    required String operationId,
    required String localId,
    required Map<String, dynamic> command,
    required Map<String, dynamic> optimistic,
    required DateTime now,
    String? expectedRevision,
  }) async {
    await initialize();
    await library.batchWrites(() async {
      final earlier = (await pendingMutations())
          .where((m) => m.payload['local_id'] == localId)
          .toList();
      // Wall clocks can move backwards. Keep causally ordered edits ahead of
      // their successors even across a restart or clock correction.
      final createdAt =
          earlier.isNotEmpty && !now.isAfter(earlier.last.createdAt)
          ? earlier.last.createdAt.add(const Duration(microseconds: 1))
          : now;
      final base = await library.database
          .customSelect(
            'SELECT revision FROM expense_confirmed WHERE local_id=?',
            variables: [Variable(localId)],
          )
          .getSingleOrNull();
      final snapshot = await library.saveLocal(
        'expense',
        localId,
        jsonEncode(optimistic),
        deleted: command['delete'] == true,
      );
      await outbox.enqueueReplacing(
        PendingMutation(
          operationId: operationId,
          account: account,
          collection: command['_receipt'] == true
              ? 'expense_receipt'
              : 'expense',
          // Append-only operations: a later edit cannot replace an in-flight write.
          entityKey: EntityKey(localId: operationId),
          type: MutationType.update,
          createdAt: createdAt,
          payload: {
            'base_revision':
                expectedRevision ?? base?.readNullable<String>('revision'),
            'predecessor': earlier.isEmpty ? null : earlier.last.operationId,
            'local_id': localId,
            'command': command,
            'generation': snapshot.generation,
            'reference': snapshot.reference,
            'deleted': snapshot.deleted,
          },
        ),
      );
    });
  }

  Future<Map<String, dynamic>> freeze(PendingMutation mutation) async {
    await initialize();
    return library.database.transaction(() async {
      final saved = await library.database
          .customSelect(
            'SELECT request FROM expense_delivery WHERE operation_id=?',
            variables: [Variable(mutation.operationId)],
          )
          .getSingleOrNull();
      if (saved != null) {
        return Map<String, dynamic>.from(
          jsonDecode(saved.read<String>('request')) as Map,
        );
      }
      final localId = mutation.payload['local_id']! as String;
      final confirmed = await library.database
          .customSelect(
            'SELECT * FROM expense_confirmed WHERE local_id=?',
            variables: [Variable(localId)],
          )
          .getSingleOrNull();
      final command = Map<String, dynamic>.from(
        mutation.payload['command'] as Map,
      );
      // Resolve references only once, then persist the exact request for every
      // retry. Creates and uploads may have completed since the user linked them.
      for (final raw in command['relations'] as List? ?? const []) {
        if (raw is Map && raw['link'] is List) {
          final resolved = <int>[];
          for (final value in raw['link'] as List) {
            final id = value as int;
            if (id <= 2147483647) {
              resolved.add(id);
              continue;
            }
            final target = await library.database
                .customSelect(
                  'SELECT remote_id FROM expense_confirmed WHERE local_id=?',
                  variables: [Variable('$id')],
                )
                .getSingleOrNull();
            if (target == null) {
              throw StateError('Waiting for linked record to upload');
            }
            resolved.add(target.read<int>('remote_id'));
          }
          raw['link'] = resolved;
        }
      }
      for (final raw in command['timeline_links'] as List? ?? const []) {
        if (raw is Map && raw['_local_event_id'] is String) {
          final target = await library.database
              .customSelect(
                'SELECT payload FROM expense_confirmed WHERE local_id=?',
                variables: [Variable(raw['_local_event_id'] as String)],
              )
              .getSingleOrNull();
          if (target == null) throw StateError('Waiting for receipt to upload');
          final event = jsonDecode(target.read<String>('payload')) as Map;
          raw.remove('_local_event_id');
          raw['event_id'] = event['event_id'];
          raw['event_time'] = event['event_time'];
        }
      }
      if (confirmed?.readNullable<int>('remote_id') case final int remoteId) {
        command['id'] = remoteId;
        command.remove('model_type');
      } else if (command['id'] != null) {
        throw StateError(
          'Cannot update an entity without a confirmed revision',
        );
      }
      final request = <String, dynamic>{
        'operation_id': mutation.operationId,
        'data': command,
        'expected_revision': mutation.payload['base_revision'],
        'domain_id': account.domainId,
      };
      if (mutation.payload['predecessor'] case final String predecessor) {
        final receipt = await library.database
            .customSelect(
              'SELECT revision FROM expense_receipts WHERE operation_id=?',
              variables: [Variable(predecessor)],
            )
            .getSingleOrNull();
        if (receipt == null) {
          throw StateError('Previous operation has not been acknowledged');
        }
        request['expected_revision'] = receipt.readNullable<String>('revision');
      }
      await library.database.customStatement(
        'INSERT INTO expense_delivery VALUES(?,?)',
        [mutation.operationId, jsonEncode(request)],
      );
      return request;
    });
  }

  Future<Map<int, String>> hashes() async {
    await initialize();
    final rows = await library.database
        .customSelect(
          'SELECT remote_id,snapshot_hash FROM expense_confirmed WHERE snapshot_hash IS NOT NULL',
        )
        .get();
    return {
      for (final row in rows)
        row.read<int>('remote_id'): row.read<String>('snapshot_hash'),
    };
  }

  Future<void> applySnapshot(
    List<Map<String, dynamic>> items,
    Set<int> authoritativeIds,
  ) async {
    await initialize();
    await library.batchWrites(() async {
      for (final item in items) {
        final payload = Map<String, dynamic>.from(item['payload'] as Map);
        final id = item['id'] as int;
        final old = await library.database
            .customSelect(
              'SELECT local_id FROM expense_confirmed WHERE remote_id=?',
              variables: [Variable(id)],
            )
            .getSingleOrNull();
        final localId = old?.read<String>('local_id') ?? '$id';
        await _confirmed(localId, id, payload, item['hash'] as String);
        await library.saveRemote(
          'expense',
          localId,
          jsonEncode(payload),
          revision: payload['revision'] as String?,
        );
      }
      final rows = await library.database
          .customSelect('SELECT local_id,remote_id FROM expense_confirmed')
          .get();
      for (final row in rows) {
        if (!authoritativeIds.contains(row.read<int>('remote_id'))) {
          final id = row.read<String>('local_id');
          // Preserve the canonical base too while an offline edit needs conflict resolution.
          if ((await library.metadata('expense', id))?.pending == true) {
            continue;
          }
          await library.removeRemote('expense', id);
          await library.database.customStatement(
            'DELETE FROM expense_confirmed WHERE local_id=?',
            [id],
          );
        }
      }
    });
  }

  Future<void> _confirmed(
    String localId,
    int remoteId,
    Map<String, dynamic>? payload,
    String? hash,
  ) => library.database.customStatement(
    '''INSERT INTO expense_confirmed VALUES(?,?,?,?,?)
      ON CONFLICT(local_id) DO UPDATE SET remote_id=excluded.remote_id,payload=excluded.payload,
      revision=excluded.revision,snapshot_hash=excluded.snapshot_hash''',
    [localId, remoteId, jsonEncode(payload), payload?['revision'], hash],
  );

  @override
  Future<void> complete(MutationReceipt receipt) async {
    await library.batchWrites(() async {
      final mutation = await outbox.operation(receipt.operationId);
      if (mutation == null) return;
      final localId = mutation.payload['local_id']! as String;
      final result = receipt.metadata['result'] as Map;
      final entity = result['entity'] == null
          ? null
          : Map<String, dynamic>.from(result['entity'] as Map);
      await _confirmed(localId, result['id'] as int, entity, null);
      final current = await library.metadata('expense', localId);
      if (current != null &&
          current.generation == mutation.payload['generation']) {
        await library.acknowledge(
          current,
          revision: entity?['revision'] as String?,
        );
        if (entity == null) {
          await library.removeRemote('expense', localId);
        } else {
          await library.saveRemote(
            'expense',
            localId,
            jsonEncode(entity),
            revision: entity['revision'] as String?,
          );
        }
      }
      await outbox.deleteOperation(receipt.operationId);
      await library.database.customStatement(
        'INSERT OR REPLACE INTO expense_receipts VALUES(?,?)',
        [receipt.operationId, entity?['revision']],
      );
      await library.database.customStatement(
        'DELETE FROM expense_delivery WHERE operation_id=?',
        [receipt.operationId],
      );
    });
  }

  @override
  Future<List<PendingMutation>> pendingMutations() async {
    await initialize();
    return outbox.pendingMutations();
  }

  @override
  Future<PendingMutation?> claimNext({
    required String workerId,
    required DateTime now,
    required Duration lease,
  }) async {
    await initialize();
    return library.database.transaction(() async {
      final seen = <String>{};
      for (final mutation in await pendingMutations()) {
        if (!seen.add(mutation.payload['local_id']! as String) ||
            !mutation.isEligibleAt(now)) {
          continue;
        }
        await library.database.customStatement(
          '''UPDATE offline_outbox SET status='claimed',
          lease_owner=?,lease_expires_at=? WHERE operation_id=?''',
          [
            workerId,
            now.add(lease).toUtc().toIso8601String(),
            mutation.operationId,
          ],
        );
        return outbox.operation(mutation.operationId);
      }
      return null;
    });
  }

  @override
  Future<void> fail(
    String operationId, {
    required SyncFailure failure,
    required DateTime retryAt,
  }) => outbox.fail(operationId, failure: failure, retryAt: retryAt);
  @override
  Future<DateTime?> nextRetryAt() => outbox.nextRetryAt();
}
