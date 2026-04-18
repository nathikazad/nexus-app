import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';

import 'package:nx_time/domain/tasks/task.dart';
import 'package:nx_time/domain/tasks/task_repository.dart';

class KgqlTaskRepository implements TaskRepository {
  KgqlTaskRepository({required this.client});

  final GraphQLClient client;

  @override
  Future<List<Task>> listForPicker() async {
    final models = await fetchKgqlModelsForRelationPicker(client, 'Task');
    return models.map((m) => Task(id: m.id, name: m.name)).toList();
  }
}
