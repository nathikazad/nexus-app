import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';

import 'package:nx_projects/data/tasks/task_attr_keys.dart';
import 'package:nx_projects/data/tasks/task_mapper.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_repository.dart';

int? _inProjectTargetId(Task t) => t.subProjectId ?? t.projectId;

/// Relation writes when [previous] and [next] differ in project or sprint target.
List<ModelRelation> _relationDeltasForUpdate(
  Task next,
  Task previous,
) {
  final out = <ModelRelation>[];
  final pOld = _inProjectTargetId(previous);
  final pNew = _inProjectTargetId(next);
  if (pOld != pNew) {
    if (previous.inProjectRelationId != null) {
      out.add(
        ModelRelation(
          id: previous.inProjectRelationId,
          delete: true,
        ),
      );
    }
    if (pNew != null) {
      out.add(
        ModelRelation(
          modelType: kTaskProjectLinkKey,
          link: [pNew],
        ),
      );
    }
  }
  if (previous.sprintId != next.sprintId) {
    if (previous.inSprintRelationId != null) {
      out.add(
        ModelRelation(
          id: previous.inSprintRelationId,
          delete: true,
        ),
      );
    }
    if (next.sprintId != null) {
      out.add(
        ModelRelation(
          modelType: kTaskSprintLinkKey,
          link: [next.sprintId!],
        ),
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
  })  : _client = client,
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
      final m = await _fetchModelByType(id, modelTypeName: name, loadSchema: loader);
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
}
