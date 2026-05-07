import 'package:nx_projects/domain/task/task.dart';

abstract class TaskRepository {
  Future<List<Task>> listAll();
  Future<Task?> getById(int id);
  Future<Task> upsert(Task task);
  Future<void> delete(int id);
  Future<List<WorkActionOption>> listWorkActions();
  Future<List<WorkActionOption>> listWorkActionsForDay(DateTime day);
  Future<void> linkWorkAction({
    required int taskId,
    required int workActionId,
    String workDescription = '',
    double? timeSpentHours,
    DateTime? startTime,
    DateTime? endTime,
  });
  Future<void> updateWorkLink({
    required int taskId,
    required int relationId,
    required int workActionId,
    String workDescription = '',
    double? timeSpentHours,
    DateTime? startTime,
    DateTime? endTime,
  });
  Future<void> deleteWorkLink({required int taskId, required int relationId});
}
