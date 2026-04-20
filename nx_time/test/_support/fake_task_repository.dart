import 'package:nx_time/domain/tasks/task.dart';
import 'package:nx_time/domain/tasks/task_repository.dart';
import 'package:nx_time/domain/tasks/task_status.dart';

/// Minimal [TaskRepository] for widget tests (empty data, no backend).
class FakeEmptyTaskRepository implements TaskRepository {
  const FakeEmptyTaskRepository();

  @override
  Future<List<Task>> listForPicker() async => const [];

  @override
  Future<List<Task>> listAll({TaskStatus? status, DateTime? onDate}) async =>
      const [];

  @override
  Future<Task?> getById(int id) async => null;

  @override
  Future<int> create(
    Task task, {
    int? parentTaskId,
    int? projectId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<int> update(Task task, {bool includeAttributes = false}) async =>
      throw UnimplementedError();

  @override
  Future<int> updateStatus({required int id, required TaskStatus status}) async =>
      throw UnimplementedError();

  @override
  Future<void> moveTaskToProject({
    required int taskId,
    int? projectId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> delete(int id) async => throw UnimplementedError();

  @override
  Future<int> linkChildTask({
    required int parentId,
    required int childId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> unlinkChildTask({
    required int parentId,
    required int relationId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<int> linkProject({
    required int taskId,
    required int projectId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> unlinkProject({
    required int taskId,
    required int relationId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<int> linkActivity({
    required int taskId,
    required int activityId,
    required String activityModelTypeName,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> unlinkActivity({
    required int taskId,
    required int relationId,
  }) async =>
      throw UnimplementedError();
}
