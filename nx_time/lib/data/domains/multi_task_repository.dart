import 'package:nx_time/domain/tasks/task.dart';
import 'package:nx_time/domain/tasks/task_repository.dart';
import 'package:nx_time/domain/tasks/task_status.dart';
import 'package:nx_time/data/domains/domain_workspace.dart';

class MultiTaskRepository implements TaskRepository {
  MultiTaskRepository(this.w);
  final DomainWorkspace w;
  @override
  Future<List<Task>> listAll({TaskStatus? status, DateTime? onDate}) async {
    final lists = await Future.wait(
      w.selectedIds.map((id) async {
        final rows = await w.tasks(id).listAll(status: status, onDate: onDate);
        w.remember(id, rows.map((r) => r.id));
        return rows;
      }),
    );
    return lists.expand((x) => x).toList();
  }

  @override
  Future<List<Task>> listForPicker() => listAll();
  @override
  Future<Task?> getById(int id) async => w.tasks(await w.owner(id)).getById(id);
  @override
  Future<int> create(Task task, {int? parentTaskId, int? projectId}) async =>
      throw StateError('Choose a destination domain before creating a task');
  @override
  Future<int> update(Task task, {bool includeAttributes = false}) async => w
      .tasks(await w.owner(task.id, write: true))
      .update(task, includeAttributes: includeAttributes);
  @override
  Future<int> updateStatus({
    required int id,
    required TaskStatus status,
  }) async => w
      .tasks(await w.owner(id, write: true))
      .updateStatus(id: id, status: status);
  @override
  Future<void> delete(int id) async =>
      w.tasks(await w.owner(id, write: true)).delete(id);
  @override
  Future<void> moveTaskToProject({required int taskId, int? projectId}) async {
    if (projectId != null) await w.sameDomain(taskId, projectId);
    await w
        .tasks(await w.owner(taskId, write: true))
        .moveTaskToProject(taskId: taskId, projectId: projectId);
  }

  @override
  Future<int> linkChildTask({
    required int parentId,
    required int childId,
  }) async {
    await w.sameDomain(parentId, childId);
    return w
        .tasks(await w.owner(parentId, write: true))
        .linkChildTask(parentId: parentId, childId: childId);
  }

  @override
  Future<void> unlinkChildTask({
    required int parentId,
    required int relationId,
  }) async => w
      .tasks(await w.owner(parentId, write: true))
      .unlinkChildTask(parentId: parentId, relationId: relationId);
  @override
  Future<int> linkProject({required int taskId, required int projectId}) async {
    await w.sameDomain(taskId, projectId);
    return w
        .tasks(await w.owner(taskId, write: true))
        .linkProject(taskId: taskId, projectId: projectId);
  }

  @override
  Future<void> unlinkProject({
    required int taskId,
    required int relationId,
  }) async => w
      .tasks(await w.owner(taskId, write: true))
      .unlinkProject(taskId: taskId, relationId: relationId);
  @override
  Future<int> linkActivity({
    required int taskId,
    required int activityId,
    required String activityModelTypeName,
  }) async {
    await w.sameDomain(taskId, activityId);
    return w
        .tasks(await w.owner(taskId, write: true))
        .linkActivity(
          taskId: taskId,
          activityId: activityId,
          activityModelTypeName: activityModelTypeName,
        );
  }

  @override
  Future<void> unlinkActivity({
    required int taskId,
    required int relationId,
  }) async => w
      .tasks(await w.owner(taskId, write: true))
      .unlinkActivity(taskId: taskId, relationId: relationId);
}
