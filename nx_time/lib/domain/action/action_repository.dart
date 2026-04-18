import 'package:nx_time/domain/action/action.dart';

/// Loads and mutates [Action] rows via the data layer (KGQL by default).
abstract class ActionRepository {
  /// Actions whose interval overlaps [dayLocal]’s calendar day (see KGQL repo).
  Future<List<Action>> listForCalendarDay(DateTime dayLocal);

  Future<Action?> getById({
    required int id,
    required String modelTypeName,
  });

  Future<int> create(Action action, String modelTypeName);

  /// Update; pass [modelTypeNameIfChanged] only when the concrete type changed.
  Future<int> update(
    Action action, {
    String? modelTypeNameIfChanged,
  });

  Future<void> delete(int id);
}
