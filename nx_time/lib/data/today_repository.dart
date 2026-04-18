import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/nx_db.dart';

import 'models/today_snapshot.dart';
import 'time_kgql_schema.dart';
import 'today_repository_interface.dart';
import 'today_snapshot_mapper.dart';

/// Cached [ModelType] for abstract [Action] (from [getKgqlModelType]).
final actionSchemaProvider = modelTypeByNameProvider(kActionModelTypeName);

/// Loads Action (+ descendant) rows for a local calendar day via `get_kgql_models`.
class KgqlTodayRepository implements TodayRepository {
  KgqlTodayRepository(this._ref);

  final Ref _ref;

  @override
  Future<TodaySnapshot> loadToday([DateTime? forDay]) async {
    final day = forDay ?? DateTime.now();
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    // Fetch actions whose start falls in [yesterday 00:00, tomorrow 00:00) so overnight
    // blocks (e.g. sleep 22:00–06:00) are included; [snapshotFromActionModels] keeps only
    // intervals that overlap the selected calendar day.
    final fetchStart = start.subtract(const Duration(days: 1));

    final schema = await _ref.read(actionSchemaProvider.future);
    final struct = buildActionActivityStruct(schema);
    final client = _ref.read(graphqlClientProvider);

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

    return snapshotFromActionModels(models, start);
  }
}

/// Loads [TodaySnapshot] via `get_kgql_models` (see [KgqlTodayRepository]).
final todayRepositoryProvider =
    Provider<TodayRepository>((ref) => KgqlTodayRepository(ref));
