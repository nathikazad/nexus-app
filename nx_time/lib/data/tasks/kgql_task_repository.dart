import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';

import 'package:nx_time/data/projects/project_attr_keys.dart';
import 'package:nx_time/data/tasks/task_attr_keys.dart';
import 'package:nx_time/data/tasks/task_mapper.dart';
import 'package:nx_time/domain/tasks/task.dart';
import 'package:nx_time/domain/tasks/task_repository.dart';
import 'package:nx_time/domain/tasks/task_status.dart';

/// Loads Task rows from **personal** and **home** domains (merged), writes to [writeDomainId].
class KgqlTaskRepository implements TaskRepository {
  KgqlTaskRepository({
    required GraphQLClient client,
    required Future<ModelType> Function() loadTaskSchema,
    required int personalDomainId,
    required int homeDomainId,
    int? writeDomainId,
  })  : _client = client,
        _loadTaskSchema = loadTaskSchema,
        _personalDomainId = personalDomainId,
        _homeDomainId = homeDomainId,
        _writeDomainId = writeDomainId ?? personalDomainId;

  final GraphQLClient _client;
  final Future<ModelType> Function() _loadTaskSchema;
  final int _personalDomainId;
  final int _homeDomainId;
  final int _writeDomainId;

  Map<String, dynamic> _taskFetchStruct(ModelType schema) {
    final base = buildKgqlStructFromSchema(schema);
    final merged = Map<String, dynamic>.from(base);
    merged[kTaskRelationKey] = {'id': true, 'name': true, 'relation': true};
    merged[kProjectRelationKey] = {'id': true, 'name': true};
    return merged;
  }

  Future<List<Model>> _fetchTasksForDomains({
    required Map<String, dynamic> filter,
    required Map<String, dynamic> struct,
  }) async {
    final a = await fetchKgqlModels(
      _client,
      filter: filter,
      struct: struct,
      domainId: _personalDomainId,
    );
    final b = await fetchKgqlModels(
      _client,
      filter: filter,
      struct: struct,
      domainId: _homeDomainId,
    );
    final byId = <int, Model>{};
    for (final m in a) {
      byId[m.id] = m;
    }
    for (final m in b) {
      byId.putIfAbsent(m.id, () => m);
    }
    final out = byId.values.toList()..sort((x, y) => x.id.compareTo(y.id));
    return out;
  }

  @override
  Future<List<Task>> listForPicker() async {
    final a = await fetchKgqlModelsForRelationPicker(
      _client,
      kTaskModelTypeName,
      domainId: _personalDomainId,
    );
    final b = await fetchKgqlModelsForRelationPicker(
      _client,
      kTaskModelTypeName,
      domainId: _homeDomainId,
    );
    final byId = <int, Task>{};
    for (final m in a) {
      byId[m.id] = taskFromModel(m);
    }
    for (final m in b) {
      byId.putIfAbsent(m.id, () => taskFromModel(m));
    }
    final out = byId.values.toList()..sort((x, y) => x.id.compareTo(y.id));
    return out;
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

    final models = await _fetchTasksForDomains(
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
    for (final dom in [_personalDomainId, _homeDomainId]) {
      final m = await fetchKgqlModelById(
        _client,
        modelTypeName: kTaskModelTypeName,
        id: id,
        struct: struct,
        domainId: dom,
      );
      if (m != null) return taskFromModel(m);
    }
    return null;
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
    return setKgqlModel(_client, req, domainId: _writeDomainId);
  }

  @override
  Future<int> update(Task task, {bool includeAttributes = false}) async {
    return setKgqlModel(
      _client,
      setModelRequestForUpdateTask(task, includeAttributes: includeAttributes),
      domainId: _writeDomainId,
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
      domainId: _writeDomainId,
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
    await setKgqlModel(
      _client,
      setModelRequestForDeleteTask(id),
      domainId: _writeDomainId,
    );
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
      domainId: _writeDomainId,
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
      domainId: _writeDomainId,
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
      domainId: _writeDomainId,
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
      domainId: _writeDomainId,
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
      domainId: _writeDomainId,
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
      domainId: _writeDomainId,
    );
  }
}
