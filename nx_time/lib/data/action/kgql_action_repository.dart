import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';

import 'package:nx_time/domain/action/action.dart';
import 'package:nx_time/domain/action/action_repository.dart';
import 'package:nx_time/data/action/action_attr_keys.dart';
import 'package:nx_time/data/action/action_mapper.dart';

/// Loads Action (+ descendant) rows via `get_kgql_models` and mutates via `set_kgql_models`.
class KgqlActionRepository implements ActionRepository {
  KgqlActionRepository({
    required GraphQLClient client,
    required Future<ModelType> Function() loadActionSchema,
  })  : _client = client,
        _loadActionSchema = loadActionSchema;

  final GraphQLClient _client;
  final Future<ModelType> Function() _loadActionSchema;

  void _log(String message) =>
      debugPrint('[nx_time kgql_action_repo] $message');

  Map<String, dynamic> _actionFetchStruct(ModelType schema) {
    final base = buildKgqlStructFromSchema(schema);
    // Ensure nested Action self-relation even if schema cache is stale.
    final merged = Map<String, dynamic>.from(base);
    merged[kActionRelationKey] = {'id': true, 'name': true, 'relation': true};
    return merged;
  }

  @override
  Future<List<Action>> listForCalendarDay(DateTime dayLocal) async {
    _log('listForCalendarDay: begin dayLocal=$dayLocal');
    final start = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
    final end = start.add(const Duration(days: 1));
    final fetchStart = start.subtract(const Duration(days: 1));

    _log('await loadActionSchema (getKgqlModelType for Action)...');
    final schema = await _loadActionSchema();
    _log('loadActionSchema ok: ${schema.name} id=${schema.id}');

    final struct = _actionFetchStruct(schema);

    _log(
      'fetchKgqlModels filter window start_time in '
      '[${fetchStart.toIso8601String()}, ${end.toIso8601String()})',
    );
    _log(
      'fetch struct top-level keys (count=${struct.length}): ${struct.keys.join(", ")}',
    );
    final fetchSw = Stopwatch()..start();
    _log('calling fetchKgqlModels(get_kgql_models) ...');
    final models = await fetchKgqlModels(
      _client,
      filter: {
        'model_type': kActionModelTypeName,
        'filters': [
          {
            'key': 'start_time',
            'op': '>=',
            'value': fetchStart.toIso8601String(),
          },
          {
            'key': 'start_time',
            'op': '<',
            'value': end.toIso8601String(),
          },
        ],
      },
      struct: struct,
    );
    fetchSw.stop();
    _log(
      'fetchKgqlModels returned ${models.length} models in ${fetchSw.elapsedMilliseconds}ms',
    );

    final out = models.map(actionFromModel).toList();
    _log('listForCalendarDay: done → ${out.length} Action(s)');
    return out;
  }

  @override
  Future<Action?> getById({
    required int id,
    required String modelTypeName,
  }) async {
    final schema = await _loadActionSchema();
    final struct = _actionFetchStruct(schema);
    final m = await fetchKgqlModelById(
      _client,
      modelTypeName: modelTypeName,
      id: id,
      struct: struct,
    );
    return m == null ? null : actionFromModel(m);
  }

  @override
  Future<int> create(
    Action action,
    String modelTypeName, {
    int? parentActionId,
  }) async {
    final req = parentActionId != null
        ? setModelRequestForCreateWithParent(
            action,
            modelTypeName,
            parentActionId: parentActionId,
          )
        : setModelRequestForCreate(action, modelTypeName);
    return setKgqlModel(_client, req);
  }

  @override
  Future<int> update(
    Action action, {
    String? modelTypeNameIfChanged,
  }) async {
    return setKgqlModel(
      _client,
      setModelRequestForUpdate(
        action,
        modelTypeNameIfChanged: modelTypeNameIfChanged,
      ),
    );
  }

  @override
  Future<void> delete(int id) async {
    await setKgqlModel(_client, setModelRequestForDelete(id));
  }

  @override
  Future<int> linkChildAction({
    required int parentId,
    required int childId,
  }) async {
    return setKgqlModel(
      _client,
      SetModelRequest(
        id: parentId,
        relations: [
          ModelRelation(
            modelType: kActionRelationKey,
            link: [childId],
          ),
        ],
      ),
    );
  }

  @override
  Future<void> unlinkChildAction({
    required int parentId,
    required int relationId,
  }) async {
    await setKgqlModel(
      _client,
      SetModelRequest(
        id: parentId,
        relations: [
          ModelRelation(
            id: relationId,
            delete: true,
          ),
        ],
      ),
    );
  }
}
