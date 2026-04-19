import 'package:nx_time/domain/action/action.dart';

/// Loads and mutates [Action] rows via the data layer (KGQL by default).
abstract class ActionRepository {
  /// Actions whose interval overlaps [dayLocal]’s calendar day (see KGQL repo).
  Future<List<Action>> listForCalendarDay(DateTime dayLocal);

  Future<Action?> getById({
    required int id,
    required String modelTypeName,
  });

  /// Creates an action; when [parentActionId] is set, links it under that parent via `action_action`.
  Future<int> create(
    Action action,
    String modelTypeName, {
    int? parentActionId,
  });

  /// Update; pass [modelTypeNameIfChanged] only when the concrete type changed.
  Future<int> update(
    Action action, {
    String? modelTypeNameIfChanged,
  });

  Future<void> delete(int id);

  /// Adds an `action_action` edge: parent → child (existing models).
  Future<int> linkChildAction({
    required int parentId,
    required int childId,
  });

  /// Removes a single `relations` row by id (does not delete the child [Action]).
  Future<void> unlinkChildAction({
    required int parentId,
    required int relationId,
  });
}
