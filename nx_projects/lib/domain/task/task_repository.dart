import 'package:nx_projects/domain/task/task.dart';

abstract class TaskRepository {
  Future<List<Task>> listAll();
  Future<Task?> getById(int id);
  Future<Task> upsert(Task task);
  Future<void> delete(int id);
}
