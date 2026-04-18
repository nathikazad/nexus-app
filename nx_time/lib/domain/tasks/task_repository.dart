import 'package:nx_time/domain/tasks/task.dart';

/// Loads tasks for pickers and task features (KGQL-backed by default).
abstract class TaskRepository {
  Future<List<Task>> listForPicker();
}
