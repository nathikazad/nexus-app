import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';

import 'package:nx_projects/data/tasks/task_attr_keys.dart';
import 'package:nx_projects/data/tasks/task_mapper.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_repository.dart';

int? _inProjectTargetId(Task t) => t.subProjectId ?? t.projectId;

/// Relation writes when [previous] and [next] differ in project or sprint target.
List<ModelRelation> _relationDeltasForUpdate(Task next, Task previous) {
  final out = <ModelRelation>[];
  final pOld = _inProjectTargetId(previous);
  final pNew = _inProjectTargetId(next);
  if (pOld != pNew) {
    if (previous.inProjectRelationId != null) {
      out.add(ModelRelation(id: previous.inProjectRelationId, delete: true));
    }
    if (pNew != null) {
      out.add(ModelRelation(modelType: kTaskProjectLinkKey, link: [pNew]));
    }
  }
  if (previous.sprintId != next.sprintId) {
    if (previous.inSprintRelationId != null) {
      out.add(ModelRelation(id: previous.inSprintRelationId, delete: true));
    }
    if (next.sprintId != null) {
      out.add(
        ModelRelation(modelType: kTaskSprintLinkKey, link: [next.sprintId!]),
      );
    }
  }
  return out;
}

class KgqlTaskRepository implements TaskRepository {
  KgqlTaskRepository({
    required GraphQLClient client,
    required Future<ModelType> Function() loadProjectTaskSchema,
    required Future<ModelType> Function() loadBugSchema,
    required Future<ModelType> Function() loadFeatureSchema,
  }) : _client = client,
       _loadProjectTaskSchema = loadProjectTaskSchema,
       _loadBugSchema = loadBugSchema,
       _loadFeatureSchema = loadFeatureSchema;

  final GraphQLClient _client;
  final Future<ModelType> Function() _loadProjectTaskSchema;
  final Future<ModelType> Function() _loadBugSchema;
  final Future<ModelType> Function() _loadFeatureSchema;
  Future<Model?> _fetchModelByType(
    int id, {
    required String modelTypeName,
    required Future<ModelType> Function() loadSchema,
  }) async {
    final schema = await loadSchema();
    final struct = buildTaskFetchStruct(schema);
    return fetchKgqlModelById(
      _client,
      modelTypeName: modelTypeName,
      id: id,
      struct: struct,
    );
  }

  /// Resolves a task by id: try [Bug], then [Feature], then base [ProjectTask].
  Future<Model?> _fetchModel(int id) async {
    final tryOrder = <(String, Future<ModelType> Function())>[
      (kBugModelTypeName, _loadBugSchema),
      (kFeatureModelTypeName, _loadFeatureSchema),
      (kTaskBaseModelTypeName, _loadProjectTaskSchema),
    ];
    for (final (name, loader) in tryOrder) {
      final m = await _fetchModelByType(
        id,
        modelTypeName: name,
        loadSchema: loader,
      );
      if (m != null) return m;
    }
    return null;
  }

  @override
  Future<List<Task>> listAll() async {
    final bugSchema = await _loadBugSchema();
    final featureSchema = await _loadFeatureSchema();
    final bugStruct = buildTaskFetchStruct(bugSchema);
    final featureStruct = buildTaskFetchStruct(featureSchema);

    final bugs = await fetchKgqlModels(
      _client,
      filter: {'model_type': kBugModelTypeName},
      struct: bugStruct,
    );
    final features = await fetchKgqlModels(
      _client,
      filter: {'model_type': kFeatureModelTypeName},
      struct: featureStruct,
    );

    final byId = <int, Model>{};
    for (final m in bugs) {
      byId[m.id] = m;
    }
    for (final m in features) {
      byId[m.id] = m;
    }

    final plainSchema = await _loadProjectTaskSchema();
    final plainStruct = buildTaskFetchStruct(plainSchema);
    final onlyProjectTask = await fetchKgqlModels(
      _client,
      filter: {'model_type': kTaskBaseModelTypeName},
      struct: plainStruct,
    );
    for (final m in onlyProjectTask) {
      final n = m.modelType?.name;
      if (n == kBugModelTypeName || n == kFeatureModelTypeName) {
        continue;
      }
      byId.putIfAbsent(m.id, () => m);
    }

    final sorted = byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    return sorted.map(taskFromModel).toList();
  }

  @override
  Future<Task?> getById(int id) async {
    final m = await _fetchModel(id);
    return m == null ? null : taskFromModel(m);
  }

  @override
  Future<Task> upsert(Task task) async {
    if (task.id <= 0) {
      final newId = await setKgqlModel(
        _client,
        setModelRequestForCreateTask(task),
      );
      final created = await getById(newId);
      if (created == null) {
        throw StateError('Created task $newId but failed to re-fetch');
      }
      return created;
    }

    final m = await _fetchModel(task.id);
    if (m == null) {
      throw ArgumentError.value(task.id, 'task.id', 'Task not found');
    }
    final previous = taskFromModel(m);
    final deltas = _relationDeltasForUpdate(task, previous);

    await setKgqlModel(
      _client,
      setModelRequestForUpdateTask(task, m, relationDeltas: deltas),
    );
    final u = await getById(task.id);
    if (u == null) {
      throw StateError('Failed to re-fetch task ${task.id} after update');
    }
    return u;
  }

  @override
  Future<void> delete(int id) async {
    await setKgqlModel(_client, setKgqlDelete(id));
  }

  @override
  Future<List<WorkActionOption>> listWorkActions() async {
    final since = DateTime.now().subtract(const Duration(days: 7));
    final models = await fetchKgqlModels(
      _client,
      filter: {
        'model_type': kTaskWorkLinkKey,
        'filters': [
          {
            'key': kTaskWorkStartTimeAttr,
            'op': '>=',
            'value': since.toIso8601String(),
          },
        ],
      },
      struct: {
        'id': true,
        'name': true,
        'model_type': {'id': true, 'name': true, 'type_kind': true},
        kTaskWorkStartTimeAttr: true,
        kTaskWorkEndTimeAttr: true,
      },
    );
    final out = <WorkActionOption>[];
    for (final m in models) {
      if (m.modelType?.name != kTaskWorkLinkKey) continue;
      out.add(
        WorkActionOption(
          id: m.id,
          name: m.name,
          startTime: m.attrDateTime(kTaskWorkStartTimeAttr),
          endTime: m.attrDateTime(kTaskWorkEndTimeAttr),
        ),
      );
    }
    out.sort((a, b) {
      final ad = a.startTime;
      final bd = b.startTime;
      if (ad == null && bd == null) return a.name.compareTo(b.name);
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });
    return out;
  }

  @override
  Future<List<WorkActionOption>> listWorkActionsForDay(DateTime day) async {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final models = await fetchKgqlModels(
      _client,
      filter: {
        'model_type': kTaskWorkLinkKey,
        'filters': [
          {
            'key': kTaskWorkStartTimeAttr,
            'op': '>=',
            'value': dayStart.toIso8601String(),
          },
          {
            'key': kTaskWorkStartTimeAttr,
            'op': '<',
            'value': dayEnd.toIso8601String(),
          },
        ],
      },
      struct: {
        'id': true,
        'name': true,
        'model_type': {'id': true, 'name': true, 'type_kind': true},
        kTaskWorkStartTimeAttr: true,
        kTaskWorkEndTimeAttr: true,
      },
    );
    final out = <WorkActionOption>[];
    for (final m in models) {
      if (m.modelType?.name != kTaskWorkLinkKey) continue;
      out.add(
        WorkActionOption(
          id: m.id,
          name: m.name,
          startTime: m.attrDateTime(kTaskWorkStartTimeAttr),
          endTime: m.attrDateTime(kTaskWorkEndTimeAttr),
        ),
      );
    }
    out.sort((a, b) {
      final ad = a.startTime;
      final bd = b.startTime;
      if (ad == null && bd == null) return a.name.compareTo(b.name);
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });
    return out;
  }

  @override
  Future<WorkActionOption> createWorkAction({
    required String name,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final id = await setKgqlModel(
      _client,
      SetModelRequest(
        modelType: kTaskWorkLinkKey,
        name: name,
        attributes: [
          SetModelAttribute(
            key: kTaskWorkStartTimeAttr,
            value: startTime.toIso8601String(),
          ),
          SetModelAttribute(
            key: kTaskWorkEndTimeAttr,
            value: endTime.toIso8601String(),
          ),
        ],
      ),
    );
    return WorkActionOption(
      id: id,
      name: name,
      startTime: startTime,
      endTime: endTime,
    );
  }

  @override
  Future<void> updateWorkActionTimes({
    required int workActionId,
    required DateTime? startTime,
    required DateTime? endTime,
  }) async {
    await setKgqlModel(
      _client,
      SetModelRequest(
        id: workActionId,
        modelType: kTaskWorkLinkKey,
        attributes: [
          SetModelAttribute(
            key: kTaskWorkStartTimeAttr,
            value: startTime?.toIso8601String(),
            delete: startTime == null,
          ),
          SetModelAttribute(
            key: kTaskWorkEndTimeAttr,
            value: endTime?.toIso8601String(),
            delete: endTime == null,
          ),
        ],
      ),
    );
  }

  List<RelationAttribute> _workRelationAttributes({
    required String workDescription,
    required double? timeSpentHours,
    required DateTime? startTime,
    required DateTime? endTime,
  }) {
    return [
      RelationAttribute(
        key: kTaskWorkDescriptionAttr,
        value: workDescription.trim(),
      ),
      RelationAttribute(
        key: kTaskWorkHoursAttr,
        value: timeSpentHours,
        delete: timeSpentHours == null,
      ),
      RelationAttribute(
        key: kTaskWorkStartTimeAttr,
        value: startTime?.toIso8601String(),
        delete: startTime == null,
      ),
      RelationAttribute(
        key: kTaskWorkEndTimeAttr,
        value: endTime?.toIso8601String(),
        delete: endTime == null,
      ),
    ];
  }

  @override
  Future<void> linkWorkAction({
    required int taskId,
    required int workActionId,
    String workDescription = '',
    double? timeSpentHours,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    await setKgqlModel(
      _client,
      SetModelRequest(
        id: taskId,
        relations: [
          ModelRelation(
            modelType: kTaskWorkLinkKey,
            link: [workActionId],
            attributes: _workRelationAttributes(
              workDescription: workDescription,
              timeSpentHours: timeSpentHours,
              startTime: startTime,
              endTime: endTime,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Future<void> updateWorkLink({
    required int taskId,
    required int relationId,
    required int workActionId,
    String workDescription = '',
    double? timeSpentHours,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    await setKgqlModel(
      _client,
      SetModelRequest(
        id: taskId,
        relations: [
          ModelRelation(
            id: relationId,
            attributes: _workRelationAttributes(
              workDescription: workDescription,
              timeSpentHours: timeSpentHours,
              startTime: startTime,
              endTime: endTime,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Future<void> deleteWorkLink({
    required int taskId,
    required int relationId,
  }) async {
    await setKgqlModel(
      _client,
      SetModelRequest(
        id: taskId,
        relations: [ModelRelation(id: relationId, delete: true)],
      ),
    );
  }
}
