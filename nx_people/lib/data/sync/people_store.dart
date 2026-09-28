import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:nx_offline/nx_offline_drift.dart';
import 'package:nx_offline/nx_offline_storage.dart';

/// One native server/user/domain/app partition. Commands and optimistic views
/// share a SQLite transaction; immutable payload files are finalized first.
class PeopleStore implements OutboxStore {
  PeopleStore(this.library, this.account)
    : outbox = DriftOutboxPersistence(
        database: library.database,
        account: account,
      );
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;
  void changed() {
    if (!_changes.isClosed) _changes.add(null);
  }

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
    await _changes.close();
    await library.close();
  }

  Future<void>? _ready;
  Future<void> initialize() => _ready ??= _initialize();
  Future<void> _initialize() async {
    await DriftOutboxPersistence.createSchema(library.database);
    await library.database.customStatement(
      '''CREATE TABLE IF NOT EXISTS people_confirmed (
      local_id TEXT PRIMARY KEY, remote_id INTEGER UNIQUE,
      payload TEXT, revision TEXT, snapshot_hash TEXT)''',
    );
    await library.database.customStatement(
      '''CREATE TABLE IF NOT EXISTS people_delivery (
      operation_id TEXT PRIMARY KEY, request TEXT NOT NULL)''',
    );
    await library.database.customStatement(
      '''CREATE TABLE IF NOT EXISTS people_receipts (
      operation_id TEXT PRIMARY KEY, revision TEXT)''',
    );
  }

  Future<Map<String, dynamic>?> get(String id) async {
    await initialize();
    id = await localId(id);
    final metadata = await library.metadata('people', id);
    if (metadata == null || metadata.deleted) return null;
    return Map<String, dynamic>.from(
      jsonDecode((await library.read('people', id))!) as Map,
    );
  }

  Future<String> localId(String id) async {
    await initialize();
    final remoteId = int.tryParse(id);
    if (remoteId == null) return id;
    final row = await library.database
        .customSelect(
          'SELECT local_id FROM people_confirmed WHERE remote_id=?',
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
          'people',
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
      final rows = await library.list('people', limit: 200, after: after);
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
            'SELECT revision FROM people_confirmed WHERE local_id=?',
            variables: [Variable(localId)],
          )
          .getSingleOrNull();
      final snapshot = await library.saveLocal(
        'people',
        localId,
        jsonEncode(optimistic),
        deleted: command['delete'] == true,
      );
      await outbox.enqueueReplacing(
        PendingMutation(
          operationId: operationId,
          account: account,
          collection: 'people',
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
    changed();
  }

  Future<Map<String, dynamic>> freeze(
    PendingMutation mutation, {
    Map<String, dynamic>? prepared,
  }) async {
    await initialize();
    return library.database.transaction(() async {
      final saved = await library.database
          .customSelect(
            'SELECT request FROM people_delivery WHERE operation_id=?',
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
            'SELECT * FROM people_confirmed WHERE local_id=?',
            variables: [Variable(localId)],
          )
          .getSingleOrNull();
      final command = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(prepared ?? mutation.payload['command'])) as Map,
      );
      Future<int> resolveId(int id) async {
        if (id <= 2147483647) return id;
        final target = await library.database
            .customSelect(
              'SELECT remote_id FROM people_confirmed WHERE local_id=?',
              variables: [Variable('$id')],
            )
            .getSingleOrNull();
        if (target == null) {
          throw StateError('Waiting for linked record to upload');
        }
        return target.read<int>('remote_id');
      }

      Future<void> resolveReferences(dynamic value) async {
        if (value is Map) {
          for (final key in value.keys.toList()) {
            final child = value[key];
            if ({'id', 'model_id', 'person_id'}.contains(key) && child is int) {
              value[key] = await resolveId(child);
            } else if (key == 'link' && child is List) {
              value[key] = [for (final id in child) await resolveId(id as int)];
            } else {
              await resolveReferences(child);
            }
          }
        } else if (value is List) {
          for (final child in value) {
            await resolveReferences(child);
          }
        }
      }

      for (final key in ['relations', 'suggestion']) {
        await resolveReferences(command[key]);
      }
      final conversation = command['_conversation'];
      if (conversation is Map && conversation['person_id'] is int) {
        conversation['person_id'] = await resolveId(
          conversation['person_id'] as int,
        );
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
              'SELECT revision FROM people_receipts WHERE operation_id=?',
              variables: [Variable(predecessor)],
            )
            .getSingleOrNull();
        if (receipt == null) {
          throw StateError('Previous operation has not been acknowledged');
        }
        request['expected_revision'] = receipt.readNullable<String>('revision');
      }
      await library.database.customStatement(
        'INSERT INTO people_delivery VALUES(?,?)',
        [mutation.operationId, jsonEncode(request)],
      );
      return request;
    });
  }

  Future<Map<int, String>> hashes() async {
    await initialize();
    final rows = await library.database
        .customSelect(
          'SELECT remote_id,snapshot_hash FROM people_confirmed WHERE snapshot_hash IS NOT NULL',
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
              'SELECT local_id FROM people_confirmed WHERE remote_id=?',
              variables: [Variable(id)],
            )
            .getSingleOrNull();
        final localId = old?.read<String>('local_id') ?? '$id';
        await _confirmed(localId, id, payload, item['hash'] as String);
        await library.saveRemote(
          'people',
          localId,
          jsonEncode(payload),
          revision: payload['revision'] as String?,
        );
      }
      final rows = await library.database
          .customSelect('SELECT local_id,remote_id FROM people_confirmed')
          .get();
      for (final row in rows) {
        if (!authoritativeIds.contains(row.read<int>('remote_id'))) {
          final id = row.read<String>('local_id');
          // Preserve the canonical base too while an offline edit needs conflict resolution.
          if ((await library.metadata('people', id))?.pending == true) {
            continue;
          }
          await library.removeRemote('people', id);
          await library.database.customStatement(
            'DELETE FROM people_confirmed WHERE local_id=?',
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
  ) async {
    // A lost create response may let the pull discover the new server ID before
    // its durable receipt arrives. Collapse that unedited duplicate on receipt.
    final prior = await library.database
        .customSelect(
          'SELECT local_id FROM people_confirmed WHERE remote_id=? AND local_id<>?',
          variables: [Variable(remoteId), Variable(localId)],
        )
        .getSingleOrNull();
    if (prior != null) {
      final duplicate = prior.read<String>('local_id');
      if ((await library.metadata('people', duplicate))?.pending == true) {
        throw const SyncTransportException(
          SyncFailure(
            kind: SyncFailureKind.conflict,
            message:
                'Two local edits refer to the same server record. Both versions were preserved.',
          ),
        );
      }
      await library.removeRemote('people', duplicate);
      await library.database.customStatement(
        'DELETE FROM people_confirmed WHERE local_id=?',
        [duplicate],
      );
    }
    await library.database.customStatement(
      '''INSERT INTO people_confirmed VALUES(?,?,?,?,?)
      ON CONFLICT(local_id) DO UPDATE SET remote_id=excluded.remote_id,payload=excluded.payload,
      revision=excluded.revision,snapshot_hash=excluded.snapshot_hash''',
      [localId, remoteId, jsonEncode(payload), payload?['revision'], hash],
    );
  }

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
      final current = await library.metadata('people', localId);
      if (current != null &&
          current.generation == mutation.payload['generation']) {
        await library.acknowledge(
          current,
          revision: entity?['revision'] as String?,
        );
        if (entity == null) {
          await library.removeRemote('people', localId);
        } else {
          await library.saveRemote(
            'people',
            localId,
            jsonEncode(entity),
            revision: entity['revision'] as String?,
          );
        }
      }
      await outbox.deleteOperation(receipt.operationId);
      await library.database.customStatement(
        'INSERT OR REPLACE INTO people_receipts VALUES(?,?)',
        [receipt.operationId, entity?['revision']],
      );
      await library.database.customStatement(
        'DELETE FROM people_delivery WHERE operation_id=?',
        [receipt.operationId],
      );
    });
    changed();
  }

  /// Resolves only a blocked entity. All its later edits are folded into a new
  /// operation; a new precondition still protects changes after this review.
  Future<void> resolveConflict(
    String operationId, {
    required bool keepLocal,
    required String replacementId,
  }) async {
    final operation = await outbox.operation(operationId);
    if (operation == null ||
        operation.status != PendingMutationStatus.blocked) {
      throw StateError('This edit is no longer awaiting review');
    }
    final conflict = await library.read('people_conflicts', operationId);
    if (conflict == null) {
      throw StateError('No server version is available for this error');
    }
    final result = jsonDecode(conflict) as Map;
    final remote = result['entity'] == null
        ? null
        : Map<String, dynamic>.from(result['entity'] as Map);
    if (keepLocal && remote == null) {
      throw StateError(
        'The server record was deleted. Copy your edit into a new record.',
      );
    }
    final localId = operation.payload['local_id'] as String;
    await library.batchWrites(() async {
      final pending = (await pendingMutations())
          .where((m) => m.payload['local_id'] == localId)
          .toList();
      final local = await get(localId);
      final current = await library.metadata('people', localId);
      final merged = <String, dynamic>{};
      final attrs = <String, dynamic>{};
      final tags = <String, dynamic>{};
      final relations = <dynamic>[];
      for (final mutation in pending) {
        final command = Map<String, dynamic>.from(
          mutation.payload['command'] as Map,
        );
        for (final attr in command.remove('attributes') as List? ?? []) {
          attrs[attr['key'] as String] = attr;
        }
        for (final tag in command.remove('tags') as List? ?? []) {
          tags[tag['system'] as String] = tag;
        }
        relations.addAll(command.remove('relations') as List? ?? []);
        merged.addAll(command);
        await outbox.deleteOperation(mutation.operationId);
        await library.database.customStatement(
          'DELETE FROM people_delivery WHERE operation_id=?',
          [mutation.operationId],
        );
        await library.removeRemote('people_conflicts', mutation.operationId);
      }
      if (current != null) await library.acknowledge(current);
      await _confirmed(localId, result['id'] as int, remote, null);
      if (remote == null) {
        await library.removeRemote('people', localId);
      } else {
        await library.saveRemote(
          'people',
          localId,
          jsonEncode(remote),
          revision: remote['revision'] as String?,
        );
      }
      if (keepLocal) {
        await enqueue(
          operationId: replacementId,
          localId: localId,
          command: {
            ...merged,
            if (attrs.isNotEmpty) 'attributes': attrs.values.toList(),
            if (tags.isNotEmpty) 'tags': tags.values.toList(),
            if (relations.isNotEmpty) 'relations': relations,
          },
          optimistic: local ?? remote!,
          now: DateTime.now().toUtc(),
          expectedRevision: remote!['revision'] as String?,
        );
      }
    });
    changed();
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
  }) async {
    await outbox.fail(operationId, failure: failure, retryAt: retryAt);
    changed();
  }

  @override
  Future<DateTime?> nextRetryAt() => outbox.nextRetryAt();
}
