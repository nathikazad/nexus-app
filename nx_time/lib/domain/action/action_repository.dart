import 'package:nx_time/domain/action/action.dart';

/// Loads and mutates [Action] rows via the data layer (KGQL by default).
abstract class ActionRepository {
  /// Actions whose interval overlaps [dayLocal]’s calendar day (see KGQL repo).
  Future<List<Action>> listForCalendarDay(DateTime dayLocal);

  /// All actions with `start_time` in the window that can overlap the Mon–Sun
  /// week starting at [mondayLocal]’s date (see KGQL: [monday−1d, monday+8d)).
  Future<List<Action>> listForWeek(DateTime mondayLocal);

  Future<Action?> getById({required int id, required String modelTypeName});

  /// Creates an action; when [parentActionId] is set, links it under that parent via `action_action`.
  Future<int> create(
    Action action,
    String modelTypeName, {
    int? parentActionId,
  });

  /// Update; pass [modelTypeNameIfChanged] only when the concrete type changed.
  Future<int> update(Action action, {String? modelTypeNameIfChanged});

  Future<void> delete(int id);

  /// Adds an `action_action` edge: parent → child (existing models).
  Future<int> linkChildAction({required int parentId, required int childId});

  /// Removes a single `relations` row by id (does not delete the child [Action]).
  Future<void> unlinkChildAction({
    required int parentId,
    required int relationId,
  });
}
