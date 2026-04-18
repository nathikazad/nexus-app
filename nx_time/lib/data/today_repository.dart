import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/nx_db.dart';

import 'fake_today_repository.dart';
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
            'value': start.toIso8601String(),
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

/// When the user is logged in ([authProvider] has a [User]), use KGQL; otherwise fake data.
final todayRepositoryProvider = Provider<TodayRepository>((ref) {
  final auth = ref.watch(authProvider);
  return auth.maybeWhen(
    data: (user) =>
        user != null ? KgqlTodayRepository(ref) : FakeTodayRepository(),
    orElse: FakeTodayRepository.new,
  );
});
