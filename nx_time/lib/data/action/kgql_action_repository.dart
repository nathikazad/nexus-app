import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/nx_db.dart';

import 'package:nx_time/domain/action/action.dart';
import 'package:nx_time/domain/action/action_repository.dart';
import 'package:nx_time/data/action/action_kgql_struct.dart';
import 'package:nx_time/data/action/action_mapper.dart';
import 'package:nx_time/data/action/action_schema_provider.dart';

/// Loads Action (+ descendant) rows via `get_kgql_models` and mutates via `set_kgql_models`.
class KgqlActionRepository implements ActionRepository {
  KgqlActionRepository(this._ref);

  final Ref _ref;

  void _log(String message) =>
      debugPrint('[nx_time kgql_action_repo] $message');

  @override
  Future<List<Action>> listForCalendarDay(DateTime dayLocal) async {
    _log('listForCalendarDay: begin dayLocal=$dayLocal');
    final start = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
    final end = start.add(const Duration(days: 1));
    final fetchStart = start.subtract(const Duration(days: 1));

    _log('await actionSchemaProvider (getKgqlModelType for Action)...');
    final schema = await _ref.read(actionSchemaProvider.future);
    _log('actionSchemaProvider ok: ${schema.name} id=${schema.id}');

    final struct = buildActionActivityStruct(schema);
    final client = _ref.read(graphqlClientProvider);

    _log(
      'fetchKgqlModels filter window start_time in '
      '[${fetchStart.toIso8601String()}, ${end.toIso8601String()})',
    );
    final models = await fetchKgqlModels(
      client,
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
    _log('fetchKgqlModels returned ${models.length} models');

    final out = models.map(actionFromModel).toList();
    _log('listForCalendarDay: done → ${out.length} Action(s)');
    return out;
  }

  @override
  Future<Action?> getById({
    required int id,
    required String modelTypeName,
  }) async {
    final schema = await _ref.read(actionSchemaProvider.future);
    final struct = buildActionActivityStruct(schema);
    final client = _ref.read(graphqlClientProvider);
    final m = await fetchKgqlModelById(
      client,
      modelTypeName: modelTypeName,
      id: id,
      struct: struct,
    );
    return m == null ? null : actionFromModel(m);
  }

  @override
  Future<int> create(Action action, String modelTypeName) async {
    final client = _ref.read(graphqlClientProvider);
    return setKgqlModel(client, setModelRequestForCreate(action, modelTypeName));
  }

  @override
  Future<int> update(
    Action action, {
    String? modelTypeNameIfChanged,
  }) async {
    final client = _ref.read(graphqlClientProvider);
    return setKgqlModel(
      client,
      setModelRequestForUpdate(
        action,
        modelTypeNameIfChanged: modelTypeNameIfChanged,
      ),
    );
  }

  @override
  Future<void> delete(int id) async {
    final client = _ref.read(graphqlClientProvider);
    await setKgqlModel(client, setModelRequestForDelete(id));
  }
}
