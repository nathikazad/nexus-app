import 'dart:convert';
import 'dart:math';
import 'package:nx_db/app_reads.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_people/data/sync/people_store.dart';
import 'package:nx_people/data/sync/people_transport.dart';

String peopleOperationId() => List.generate(
  24,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

class PeopleConflict implements Exception {
  PeopleConflict(this.local, this.remote);
  final Map<String, dynamic> local;
  final Map<String, dynamic>? remote;
  @override
  String toString() =>
      'This record changed elsewhere. Your edit has been kept for review.';
}

/// All native reads and edits use one server/user/domain partition. A downloaded
/// manifest is authoritative; a foreground page never implies full coverage.
class PeopleDataRepository {
  PeopleDataRepository({
    required this.reads,
    required this.remote,
    required this.domainId,
    this.store,
    this.onPending,
    this.onChanged,
  });
  final AppReads reads;
  final PeopleTransport remote;
  final int domainId;
  final PeopleStore? store;
  final void Function()? onPending, onChanged;
  final Map<String, String> _webOperations = {};
  static int _lastTemporaryId = 0;

  Future<bool> isComplete() async =>
      store != null &&
      await store!.library.read('people_state', 'coverage') != null;

  Future<List<Map<String, dynamic>>> rows(
    String kind, {
    bool hydrate = true,
  }) async {
    final native = store;
    if (native == null) return reads.items(query: {'kind': kind});
    if (hydrate && !await isComplete()) {
      try {
        await native.acceptLive(await reads.items(query: {'kind': kind}));
      } catch (_) {
        // A first offline launch may have only a locally created record.
        // Keep it readable without pretending that the library is complete.
        final cached = (await native.all())
            .where((e) => e['kind'] == kind)
            .toList();
        if (cached.isEmpty) rethrow;
      }
    }
    final result = (await native.all())
        .where((e) => e['kind'] == kind)
        .toList();
    if (kind == 'message') {
      for (final operation in await native.pendingMutations()) {
        final payload = (operation.payload['command'] as Map)['_conversation'];
        if (payload is! Map) continue;
        final conversation = await native.get(
          operation.payload['local_id'] as String,
        );
        var index = 0;
        for (final message in payload['messages'] as List? ?? []) {
          result.removeWhere(
            (row) =>
                row['message']?['externalMessageId'] ==
                    message['external_message_id'] &&
                row['conversation_id'] == conversation?['id'],
          );
          result.add({
            'kind': 'message',
            'conversation_id': conversation?['id'],
            'message': {
              'id': 'pending:${operation.operationId}:${index++}',
              'provider': payload['provider'],
              'externalAccountId': payload['external_account_id'],
              'externalThreadId': payload['external_thread_id'],
              'externalMessageId': message['external_message_id'],
              'messageTime': message['message_time'],
              'sequence': message['sequence'],
              'rawPayload': message['raw_payload'],
            },
          });
        }
      }
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> messages(int conversationId) async {
    if (store == null) {
      return reads.items(query: {'kind': 'messages:$conversationId'});
    }
    if (!await isComplete() && conversationId <= 2147483647) {
      try {
        await store!.acceptLive(
          await reads.items(query: {'kind': 'messages:$conversationId'}),
        );
      } catch (_) {
        /* Cached conversation messages remain readable offline. */
      }
    }
    final conversation = await get(conversationId);
    return (await rows(
      'message',
      hydrate: false,
    )).where((row) => row['conversation_id'] == conversation?['id']).toList();
  }

  Future<Map<String, dynamic>?> get(int id) async {
    if (store case final native?) {
      final local = await native.localId('$id');
      if ((await native.library.metadata('people', local))?.deleted == true) {
        return null;
      }
      final row = await native.get(local);
      if (row != null || await isComplete()) return row;
    }
    try {
      final row = await reads.read('$id');
      await store?.acceptLive([row]);
      return row;
    } on AppReadException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<ModelType> schema(String name) async {
    var metadata = await store?.get('0');
    if (metadata == null) {
      metadata = {'id': 0, 'kind': 'metadata', ...await reads.read('initial')};
      await store?.acceptLive([metadata]);
    }
    final matches = (metadata['schemas'] as List).where(
      (s) => s['name'] == name,
    );
    if (matches.isEmpty) throw StateError('Schema $name is unavailable');
    return ModelType.fromJson(Map<String, dynamic>.from(matches.first as Map));
  }

  Future<List<Model>> models(String kind) async {
    final values = await rows(kind);
    if (store == null) return values.map(Model.fromJson).toList();
    final all = await store!.all();
    final byId = {for (final row in all) row['id']: row};
    final aliases = await store!.library.database
        .customSelect('SELECT local_id,remote_id FROM people_confirmed')
        .get();
    for (final alias in aliases) {
      final local = int.tryParse(alias.read<String>('local_id'));
      final remote = alias.read<int>('remote_id');
      final row = byId[local] ?? byId[remote];
      if (row != null) {
        byId[remote] = row;
        if (local != null) byId[local] = row;
      }
    }
    final incoming = <dynamic, List<(Map, Map<String, dynamic>)>>{};
    for (final other in all) {
      for (final edge in other['relations'] as List? ?? []) {
        final target = byId[edge['model_id']];
        if (target != null) {
          incoming.putIfAbsent(target['id'], () => []).add((
            edge as Map,
            other,
          ));
        }
      }
    }
    final result = <Model>[];
    const families = {
      'Person',
      'Contact',
      'Conversation',
      'Meet',
      'Company',
      'School',
      'University',
      'Education',
      'Place',
    };
    final complete = await isComplete();
    for (final value in values) {
      final row = Map<String, dynamic>.from(value);
      final groups = <String, List<dynamic>>{
        if (complete)
          for (final type in families) type: [],
      };
      final edges = <Map<String, dynamic>>[];
      void add(Map edge, Map<String, dynamic> target) {
        final type = target['kind'] as String;
        final group = groups.putIfAbsent(type, () => []);
        if (!group.any((r) => r['id'] == target['id'])) {
          group.add({
            for (final key in target.keys)
              if (!families.contains(key) && key != 'relations')
                key: target[key],
          });
        }
        if (edges.any(
          (existing) => edge['relation_id'] != null
              ? existing['relation_id'] == edge['relation_id']
              : existing['model_id'] == target['id'] &&
                    existing['relation_name'] == edge['relation_name'],
        )) {
          return;
        }
        edges.add({
          ...Map<String, dynamic>.from(edge),
          'model_id': target['id'],
          'model_type': type,
          'name': target['name'],
          'description': target['description'],
        });
      }

      for (final edge in row['relations'] as List? ?? []) {
        final target = byId[edge['model_id']];
        if (target != null) {
          add(edge as Map, target);
        } else if (!complete || !families.contains(edge['model_type'])) {
          edges.add(Map<String, dynamic>.from(edge as Map));
        }
      }
      // Locally created meetings/conversations link from the other endpoint.
      for (final incomingEdge in incoming[row['id']] ?? []) {
        add(incomingEdge.$1, incomingEdge.$2);
      }
      row.addAll(groups);
      row['relations'] = edges;
      result.add(Model.fromJson(row));
    }
    return result;
  }

  Future<Model?> model(int id) async {
    final row = await get(id);
    if (row == null) return null;
    if (store == null) return Model.fromJson(row);
    final candidates = await models(row['kind'] as String);
    return candidates.where((m) => m.id == row['id']).firstOrNull;
  }

  Future<Map<String, dynamic>> conversation(
    Map<String, dynamic> payload,
  ) async {
    final existing = (await rows('Conversation'))
        .where(
          (r) =>
              r['provider'] == payload['provider'] &&
              r['external_account_id'] == payload['external_account_id'] &&
              r['external_thread_id'] == payload['external_thread_id'],
        )
        .firstOrNull;
    final type = await schema('Conversation');
    final optimistic = <String, dynamic>{
      ...?existing,
      'kind': 'Conversation',
      'model_type_id': type.id,
      'model_type': {'id': type.id, 'name': 'Conversation'},
      'relations': [
        {
          'model_id': payload['person_id'],
          'model_type': 'Person',
          'relation_name': 'has_conversation',
        },
      ],
      'name': payload['name'] ?? '',
      'description': payload['summary'] ?? '',
      for (final key in [
        'provider',
        'external_account_id',
        'external_thread_id',
        'response_pending',
        'last_message_at',
      ])
        if (payload[key] != null) key: payload[key],
    };
    final command = <String, dynamic>{
      '_conversation': payload,
      if (existing != null) 'id': existing['id'],
    };
    final id = await save(
      command,
      optimistic: optimistic,
      expectedRevision: existing?['revision'] as String?,
    );
    return {
      'status': store == null ? 'APPLIED' : 'QUEUED',
      'conversation_id': id,
    };
  }

  Future<int> set(SetModelRequest request) async {
    final command = request.toJson();
    final old = request.id == null ? null : await get(request.id!);
    if (request.id != null && old == null) {
      throw StateError('Record is no longer available');
    }
    final kind = old?['kind'] as String? ?? request.modelType!;
    final type = await schema(kind);
    final optimistic = optimisticPeopleModel(old, command, type.id, kind);
    return save(
      command,
      optimistic: optimistic,
      expectedRevision: old?['revision'] as String?,
    );
  }

  Future<int> save(
    Map<String, dynamic> command, {
    required Map<String, dynamic> optimistic,
    required String? expectedRevision,
  }) async {
    final key = jsonEncode([command, expectedRevision]);
    final operation = store == null
        ? _webOperations.putIfAbsent(key, peopleOperationId)
        : peopleOperationId();
    final requested = command['id'] as int?;
    if (store case final native?) {
      final localId = requested == null
          ? '${_lastTemporaryId = max(DateTime.now().microsecondsSinceEpoch, _lastTemporaryId + 1)}'
          : await native.localId('$requested');
      await native.enqueue(
        operationId: operation,
        localId: localId,
        command: command,
        optimistic: {...optimistic, 'id': requested ?? int.parse(localId)},
        expectedRevision: expectedRevision,
        now: DateTime.now().toUtc(),
      );
      onChanged?.call();
      onPending?.call();
      return requested ?? int.parse(localId);
    }
    final response = await remote.execute({
      'operation_id': operation,
      'data': command,
      'expected_revision': expectedRevision,
      'domain_id': domainId,
    });
    _webOperations.remove(key);
    if (response['status'] == 'conflict') {
      throw PeopleConflict(
        optimistic,
        response['entity'] == null
            ? null
            : Map<String, dynamic>.from(response['entity'] as Map),
      );
    }
    onChanged?.call();
    return response['id'] as int;
  }
}

Map<String, dynamic> optimisticPeopleModel(
  Map<String, dynamic>? old,
  Map<String, dynamic> command,
  int typeId,
  String kind,
) {
  final row = <String, dynamic>{
    'name': '',
    'model_type_id': typeId,
    'model_type': {'id': typeId, 'name': kind},
    'kind': kind,
    ...?old,
  };
  for (final key in ['name', 'description', 'suggestion', 'meta']) {
    if (command.containsKey(key)) row[key] = command[key];
  }
  for (final attr in command['attributes'] as List? ?? []) {
    row[attr['key'] as String] = attr['delete'] == true ? null : attr['value'];
  }
  final tags = Map<String, dynamic>.from(row['tags'] as Map? ?? {});
  for (final tag in command['tags'] as List? ?? []) {
    tags[tag['system'] as String] = tag['clear'] == true ? [] : tag['nodes'];
  }
  row['tags'] = tags;
  final edges = [
    for (final edge in row['relations'] as List? ?? [])
      Map<String, dynamic>.from(edge as Map),
  ];
  for (final relation in command['relations'] as List? ?? []) {
    if (relation['delete'] == true) {
      edges.removeWhere((e) => e['relation_id'] == relation['id']);
    } else {
      for (final id in relation['link'] as List? ?? []) {
        edges.removeWhere(
          (e) =>
              e['model_id'] == id &&
              e['relation_name'] == relation['relation_name'],
        );
        edges.add({
          'model_id': id,
          'model_type': relation['model_type'],
          'relation_name': relation['relation_name'],
          'relation_attributes': relation['attributes'] ?? [],
        });
      }
    }
  }
  row['relations'] = edges;
  return row;
}
