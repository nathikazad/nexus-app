import 'package:nx_time/domain/tasks/task.dart';
import 'package:nx_time/domain/tasks/task_status.dart';

/// Loads and mutates [Task] rows via the data layer (KGQL by default).
abstract class TaskRepository {
  /// Minimal rows for relation pickers.
  Future<List<Task>> listForPicker();

  /// Tasks with optional filters on status and calendar [onDate] (matches `date` attribute day).
  Future<List<Task>> listAll({TaskStatus? status, DateTime? onDate});

  Future<Task?> getById(int id);

  /// Creates a task; optional [parentTaskId] links via `has_subtask`; [projectId] via `in_project`.
  Future<int> create(Task task, {int? parentTaskId, int? projectId});

  /// Persists name and description. Set [includeAttributes] when saving a full [Task]
  /// from [getById] (status, tags, date, times).
  Future<int> update(Task task, {bool includeAttributes = false});

  /// Sets status only; does not send other attributes (safe for list/quick actions).
  Future<int> updateStatus({required int id, required TaskStatus status});

  /// Replaces the task's project link: unlinks current `in_project` when present, then
  /// links [projectId] if non-null.
  Future<void> moveTaskToProject({required int taskId, int? projectId});

  Future<void> delete(int id);

  Future<int> linkChildTask({required int parentId, required int childId});

  Future<void> unlinkChildTask({
    required int parentId,
    required int relationId,
  });

  Future<int> linkProject({required int taskId, required int projectId});

  Future<void> unlinkProject({required int taskId, required int relationId});

  /// Links an existing activity row (concrete Action subtype) via `link_to_action`.
  Future<int> linkActivity({
    required int taskId,
    required int activityId,
    required String activityModelTypeName,
  });

  Future<void> unlinkActivity({required int taskId, required int relationId});
}
