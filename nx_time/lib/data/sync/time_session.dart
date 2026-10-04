import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:gql/ast.dart';
import 'package:gql/language.dart';
import 'package:crypto/crypto.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/app_reads.dart';
import 'package:nx_db/app_sync.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:nx_offline/nx_offline_storage.dart';
import 'package:nx_time/data/sync/time_store.dart';
import 'package:nx_time/data/sync/time_transport.dart';
import 'package:nx_time/data/sync/time_synchronizer.dart';
import 'package:nx_time/data/sync/time_graph.dart';

String timeOperationId() => List.generate(
  24,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

/// A single immutable server/user/domain session. Never reused after sign-out.
class TimeSession {
  TimeSession(this.user, this.domainId, this.remote, {TimeStore? storage}) {
    final account = AccountIdentity(
      serverId: user.preset.serverId,
      userId: user.userId,
      application: 'nx_time_v1',
      domainId: domainId,
    );
    store = storage ?? TimeStore(FileLibrary.application(account.key), account);
    http = NexusAuthenticatedClient(
      preset: user.preset,
      userId: user.userId,
      domainId: domainId,
    );
    reads = AppReads(http, Uri.parse(resolve(user.preset).imageHttp), 'time');
    const clock = SystemClock();
    outbox = OutboxProcessor(
      store: store,
      handlers: [TimeMutationHandler(store, TimeTransport(reads))],
      clock: clock,
      workerId: timeOperationId(),
      scheduler: RetryScheduler(clock: clock),
    );
    sync = SyncSupervisor<int>(
      reconciler: TimeReconciler(
        store,
        AppSyncClient(remote, 'time').session,
        onChanged: store.changed,
      ),
      prepare: () async {
        await outbox.process();
      },
      retryDelay: const Duration(seconds: 5),
    );
    client = GraphQLClient(link: TimeLocalLink(this), cache: GraphQLCache());
  }
  final User user;
  final int domainId;
  final GraphQLClient remote;
  late final TimeStore store;
  late final NexusAuthenticatedClient http;
  late final AppReads reads;
  late final OutboxProcessor outbox;
  late final SyncSupervisor<int> sync;
  late final GraphQLClient client;
  bool closed = false;
  final Map<String, Future<Response>> _fetching = {};
  final Map<String, DateTime> _lastFetch = {};
  final Map<String, Request> _queries = {};
  static int _lastId = 0;
  Future<void>? _initial;

  Future<void> synchronize(SyncReason reason) async {
    if (closed) return;
    await sync.requestFull(reason);
    // Refresh only previously requested aggregate/preferences views. Base records
    // come from the verified manifest, not from these non-authoritative views.
    await Future.wait(
      _queries.entries.map((e) => _fetch(e.key, e.value).then((_) {})),
    );
  }

  Future<void> ready() async {
    if (await store.library.read('time_state', 'coverage') != null) return;
    if ((await store.all()).any((r) => r['id'] != 0)) return;
    final run = _initial ??= sync.requestFull(SyncReason.appStarted);
    try {
      await run;
    } finally {
      _initial = null;
    }
  }

  Future<List<Map<String, dynamic>>> schemas() async {
    var metadata = await store.get('0');
    if (metadata == null) {
      metadata = {'id': 0, 'kind': 'metadata', ...await reads.read('initial')};
      await store.acceptLive([metadata]);
    }
    final flattened = <int, Map<String, dynamic>>{};
    void visit(dynamic x) {
      if (x is! Map) return;
      final m = Map<String, dynamic>.from(x);
      if (m['id'] is int) flattened[m['id'] as int] = m;
      for (final c in m['children'] as List? ?? []) visit(c);
    }

    for (final x in metadata['schemas'] as List? ?? []) visit(x);
    return flattened.values.toList();
  }

  Future<TimeGraph> graph() async {
    await ready();
    final rows = await store.all();
    // References created offline retain their local IDs until acknowledged.
    final aliases = await store.library.database
        .customSelect('SELECT local_id,remote_id FROM time_confirmed')
        .get();
    final ids = {
      for (final a in aliases)
        int.tryParse(a.read<String>('local_id')): a.read<int>('remote_id'),
    };
    for (final r in rows) {
      for (final edge in r['relations'] as List? ?? []) {
        edge['model_id'] = ids[edge['model_id']] ?? edge['model_id'];
      }
    }
    return TimeGraph(
      rows,
      aliases: {
        for (final e in ids.entries)
          if (e.key != null) e.key!: e.value,
      },
    );
  }

  Future<int> save(Map<String, dynamic> command) async {
    if (closed) throw StateError('Domain session closed');
    final requested = command['id'] as int?;
    final old = requested == null ? null : await store.get('$requested');
    if (requested != null && old == null)
      throw StateError('Download this record before editing offline');
    final kind = old?['kind'] as String? ?? command['model_type'] as String;
    final schema = (await schemas())
        .where((s) => s['name'] == kind)
        .firstOrNull;
    if (schema == null)
      throw StateError('Schema $kind has not been downloaded');
    final id =
        requested ??
        (_lastId = max(DateTime.now().microsecondsSinceEpoch, _lastId + 1));
    final types = await schemas();
    final byId = {for (final t in types) t['id']: t};
    final families = <String>{kind};
    void ancestors(Map type) {
      for (final parent in [
        type['parent'],
        ...(type['mixins'] as List? ?? []),
      ]) {
        if (parent is Map &&
            parent['name'] is String &&
            families.add(parent['name'] as String)) {
          ancestors(byId[parent['id']] ?? parent);
        }
      }
    }

    ancestors(schema);
    final row = <String, dynamic>{
      'id': id,
      'name': '',
      'created_at': DateTime.now().toIso8601String(),
      'kind': kind,
      'model_type_id': schema['id'],
      'model_type': {'id': schema['id'], 'name': kind},
      'families': families.toList(),
      ...?old,
    };
    for (final k in ['name', 'description', 'suggestion', 'meta']) {
      if (command.containsKey(k)) row[k] = command[k];
    }
    final attrs = command['attributes'] as List? ?? [];
    for (final a in attrs) {
      final key = a['key'] as String;
      if (key == 'participants' && a['value'] is Map) {
        final participants = Map<String, dynamic>.from(row[key] as Map? ?? {});
        for (final e in (a['value'] as Map).entries) {
          participants[e.key as String] = {
            ...?participants[e.key] as Map?,
            ...e.value as Map,
          };
        }
        row[key] = participants;
      } else {
        row[key] = a['delete'] == true ? null : a['value'];
      }
    }
    if ((row['families'] as List).contains('Task')) {
      row['status'] ??= 'todo';
      if (attrs.any((a) => a['key'] == 'status')) {
        if (row['status'] == 'done') {
          row['completed_at'] = (old?['status'] == 'done')
              ? (old?['completed_at'])
              : (row['completed_at'] ?? DateTime.now().toIso8601String());
        } else {
          row['completed_at'] = null;
        }
      }
    }
    final edges = [
      for (final e in row['relations'] as List? ?? [])
        Map<String, dynamic>.from(e as Map),
    ];
    for (final relation in command['relations'] as List? ?? []) {
      if (relation['delete'] == true) {
        if (relation['id'] == 0)
          throw StateError(
            'Wait for this new relationship to sync before removing it',
          );
        edges.removeWhere((e) => e['relation_id'] == relation['id']);
      } else {
        if (relation['create'] != null)
          throw StateError(
            'Create the related record separately before linking it offline',
          );
        final targetType = relation['model_type'];
        final definition = (schema['relations'] as List? ?? [])
            .where((r) => r['target_model_type'] == targetType)
            .firstOrNull;
        for (final target in relation['link'] as List? ?? []) {
          edges.add({
            'model_id': target,
            'model_type': targetType,
            'relation_name':
                relation['relation_name'] ?? definition?['relation_name'],
          });
        }
      }
    }
    row['relations'] = edges;
    final local = requested == null ? '$id' : await store.localId('$requested');
    await store.enqueue(
      operationId: timeOperationId(),
      localId: local,
      command: command,
      optimistic: row,
      now: DateTime.now().toUtc(),
      expectedRevision: old?['revision'] as String?,
    );
    outbox.schedule();
    return id;
  }

  Future<Response> cached(Request request) async {
    final key = sha256
        .convert(
          utf8.encode(
            jsonEncode({
              'query': printNode(request.operation.document),
              'name': request.operation.operationName,
              'variables': request.variables,
            }),
          ),
        )
        .toString();
    _queries[key] = request;
    final saved = await store.library.read('time_queries', key);
    if (saved != null) {
      if (DateTime.now().difference(_lastFetch[key] ?? DateTime(1970)) >
          const Duration(seconds: 30))
        unawaited(
          _fetch(
            key,
            request,
          ).catchError((Object e) => Response(response: const {}, data: null)),
        );
      return Response(
        response: const {},
        data: Map<String, dynamic>.from(jsonDecode(saved) as Map),
      );
    }
    return _fetch(key, request);
  }

  Future<Response> _fetch(String key, Request request) =>
      _fetching.putIfAbsent(key, () async {
        try {
          _lastFetch[key] = DateTime.now();
          final response = await remote.link
              .request(request)
              .first
              .timeout(const Duration(seconds: 20));
          if (response.errors?.isNotEmpty == true || response.data == null)
            throw StateError('Could not refresh this view');
          if (closed) return response;
          final data = jsonEncode(response.data);
          final previous = await store.library.read('time_queries', key);
          await store.library.saveRemote('time_queries', key, data);
          if (previous != null && previous != data) store.changed();
          return response;
        } finally {
          _fetching.remove(key);
        }
      });
  Future<void> close() async {
    closed = true;
    await outbox.close();
    await sync.close();
    await Future.wait(
      _fetching.values.map((f) => f.then((_) {}).catchError((Object _) {})),
    );
    http.close();
    await reads.close();
    await store.close();
    remote.link.dispose();
  }
}

class TimeLocalLink extends Link {
  TimeLocalLink(this.session);
  final TimeSession session;
  @override
  Stream<Response> request(Request request, [NextLink? forward]) async* {
    if (request.isSubscription) {
      yield* session.remote.link.request(request);
      return;
    }
    final document = request.operation.document;
    // Match the actual root field, never operation labels supplied by callers.
    final operation = document.definitions
        .whereType<OperationDefinitionNode>()
        .first;
    final fields = operation.selectionSet.selections
        .whereType<FieldNode>()
        .where((f) => f.name.value != '__typename')
        .toList();
    if (fields.length != 1) {
      if (request.isMutation)
        throw UnsupportedError('This edit requires a connection');
      yield await session.cached(request);
      return;
    }
    final field = fields.single;
    final name = field.name.value, resultKey = field.alias?.value ?? name;
    final v = request.variables;
    dynamic result;
    switch (name) {
      case 'setKgqlModels':
        final input = Map<String, dynamic>.from(v['input'] as Map);
        if (input['domainId'] != null && input['domainId'] != session.domainId)
          throw StateError('Wrong domain');
        result = {
          '__typename': 'SetKgqlModelsPayload',
          'json': {
            'id': await session.save(
              Map<String, dynamic>.from(input['data'] as Map),
            ),
          },
        };
      case 'getKgqlModels':
        if (v['domainId'] != null && v['domainId'] != session.domainId)
          throw StateError('Wrong domain');
        result = (await session.graph()).query(
          v['filter'] as Map? ?? {},
          v['struct'] as Map? ?? {},
        );
      case 'getKgqlModelType':
        final schemas = await session.schemas();
        final wanted = (v['input'] as Map?)?['model_types'] as List?;
        if (wanted == null || wanted.isEmpty) {
          result = schemas;
        } else {
          result = schemas
              .where(
                (s) => wanted.contains(s['name']) || wanted.contains(s['id']),
              )
              .toList();
        }
      case 'getKgqlCalendar':
        result = (await session.graph()).calendar(
          DateTime.parse(v['from'] as String),
          DateTime.parse(v['until'] as String),
          history: v['actual'] == true,
        );
      default:
        if (request.isMutation) {
          yield* session.remote.link.request(request);
          return;
        }
        yield await session.cached(request);
        return;
    }
    yield Response(
      response: const {},
      data: {
        '__typename': request.isMutation ? 'Mutation' : 'Query',
        resultKey: result,
      },
    );
  }
}
