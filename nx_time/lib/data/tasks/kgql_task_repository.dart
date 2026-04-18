import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/nx_db.dart';

import 'package:nx_time/domain/tasks/task.dart';
import 'package:nx_time/domain/tasks/task_repository.dart';

class KgqlTaskRepository implements TaskRepository {
  KgqlTaskRepository(this._ref);

  final Ref _ref;

  @override
  Future<List<Task>> listForPicker() async {
    final client = _ref.read(graphqlClientProvider);
    final models = await fetchKgqlModelsForRelationPicker(client, 'Task');
    return models.map((m) => Task(id: m.id, name: m.name)).toList();
  }
}
