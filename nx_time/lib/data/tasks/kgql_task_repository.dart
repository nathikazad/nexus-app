import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';

import 'package:nx_time/data/projects/project_attr_keys.dart';
import 'package:nx_time/data/tasks/task_attr_keys.dart';
import 'package:nx_time/data/tasks/task_mapper.dart';
import 'package:nx_time/domain/tasks/task.dart';
import 'package:nx_time/domain/tasks/task_repository.dart';
import 'package:nx_time/domain/tasks/task_status.dart';

/// Loads Task rows via `get_kgql_models` and mutates via `set_kgql_models`.
class KgqlTaskRepository implements TaskRepository {
  KgqlTaskRepository({
    required GraphQLClient client,
    required Future<ModelType> Function() loadTaskSchema,
  })  : _client = client,
        _loadTaskSchema = loadTaskSchema;

  final GraphQLClient _client;
  final Future<ModelType> Function() _loadTaskSchema;

  void _log(String message) => debugPrint('[nx_time kgql_task_repo] $message');

  Map<String, dynamic> _taskFetchStruct(ModelType schema) {
    final base = buildKgqlStructFromSchema(schema);
    final merged = Map<String, dynamic>.from(base);
    merged[kTaskRelationKey] = {'id': true, 'name': true, 'relation': true};
    merged[kProjectRelationKey] = {'id': true, 'name': true};
    return merged;
  }

  @override
  Future<List<Task>> listForPicker() async {
    final models = await fetchKgqlModelsForRelationPicker(
      _client,
      kTaskModelTypeName,
    );
    return models.map(taskFromModel).toList();
  }

  @override
  Future<List<Task>> listAll({
    TaskStatus? status,
    DateTime? onDate,
  }) async {
    final schema = await _loadTaskSchema();
    final struct = _taskFetchStruct(schema);

    final filters = <Map<String, dynamic>>[];
    if (status != null) {
      filters.add({
        'key': kTaskAttrStatus,
        'op': '=',
        'value': status.kgqlValue,
      });
    }
    if (onDate != null) {
      final start = DateTime(onDate.year, onDate.month, onDate.day);
      final end = start.add(const Duration(days: 1));
      filters.add({
        'key': kTaskAttrDate,
        'op': '>=',
        'value': start.toIso8601String(),
      });
      filters.add({
        'key': kTaskAttrDate,
        'op': '<',
        'value': end.toIso8601String(),
      });
    }

    _log(
      'listAll filters=${filters.isEmpty ? "none" : filters.length} structKeys=${struct.keys.join(",")}',
    );

    final models = await fetchKgqlModels(
      _client,
      filter: {
        'model_type': kTaskModelTypeName,
        if (filters.isNotEmpty) 'filters': filters,
      },
      struct: struct,
    );
    return models.map(taskFromModel).toList();
  }

  @override
  Future<Task?> getById(int id) async {
    final schema = await _loadTaskSchema();
    final struct = _taskFetchStruct(schema);
    final m = await fetchKgqlModelById(
      _client,
      modelTypeName: kTaskModelTypeName,
      id: id,
      struct: struct,
    );
    return m == null ? null : taskFromModel(m);
  }

  @override
  Future<int> create(
    Task task, {
    int? parentTaskId,
    int? projectId,
  }) async {
    final req = setModelRequestForCreateTask(
      task,
      parentTaskId: parentTaskId,
      projectId: projectId,
    );
    return setKgqlModel(_client, req);
  }

  @override
  Future<int> update(Task task, {bool includeAttributes = false}) async {
    return setKgqlModel(
      _client,
      setModelRequestForUpdateTask(task, includeAttributes: includeAttributes),
    );
  }

  @override
  Future<int> updateStatus({required int id, required TaskStatus status}) async {
    return setKgqlModel(
      _client,
      SetModelRequest(
        id: id,
        attributes: [
          SetModelAttribute(key: kTaskAttrStatus, value: status.kgqlValue),
        ],
      ),
    );
  }

  @override
  Future<void> moveTaskToProject({
    required int taskId,
    int? projectId,
  }) async {
    final task = await getById(taskId);
    if (task == null) {
      throw ArgumentError.value(taskId, 'taskId', 'Task not found');
    }
    if (task.projectId == projectId) return;
    final relId = task.projectRelationId;
    if (relId != null) {
      await unlinkProject(taskId: taskId, relationId: relId);
    }
    if (projectId != null) {
      await linkProject(taskId: taskId, projectId: projectId);
    }
  }

  @override
  Future<void> delete(int id) async {
    await setKgqlModel(_client, setModelRequestForDeleteTask(id));
  }

  @override
  Future<int> linkChildTask({
    required int parentId,
    required int childId,
  }) async {
    return setKgqlModel(
      _client,
      SetModelRequest(
        id: parentId,
        relations: [
          ModelRelation(
            modelType: kTaskRelationKey,
            link: [childId],
          ),
        ],
      ),
    );
  }

  @override
  Future<void> unlinkChildTask({
    required int parentId,
    required int relationId,
  }) async {
    await setKgqlModel(
      _client,
      SetModelRequest(
        id: parentId,
        relations: [
          ModelRelation(
            id: relationId,
            delete: true,
          ),
        ],
      ),
    );
  }

  @override
  Future<int> linkProject({
    required int taskId,
    required int projectId,
  }) async {
    return setKgqlModel(
      _client,
      SetModelRequest(
        id: taskId,
        relations: [
          ModelRelation(
            modelType: kProjectRelationKey,
            link: [projectId],
          ),
        ],
      ),
    );
  }

  @override
  Future<void> unlinkProject({
    required int taskId,
    required int relationId,
  }) async {
    await setKgqlModel(
      _client,
      SetModelRequest(
        id: taskId,
        relations: [
          ModelRelation(
            id: relationId,
            delete: true,
          ),
        ],
      ),
    );
  }

  @override
  Future<int> linkActivity({
    required int taskId,
    required int activityId,
    required String activityModelTypeName,
  }) async {
    return setKgqlModel(
      _client,
      SetModelRequest(
        id: taskId,
        relations: [
          ModelRelation(
            modelType: activityModelTypeName,
            link: [activityId],
          ),
        ],
      ),
    );
  }

  @override
  Future<void> unlinkActivity({
    required int taskId,
    required int relationId,
  }) async {
    await setKgqlModel(
      _client,
      SetModelRequest(
        id: taskId,
        relations: [
          ModelRelation(
            id: relationId,
            delete: true,
          ),
        ],
      ),
    );
  }
}
