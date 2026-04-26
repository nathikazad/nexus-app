import 'package:nx_db/kgql.dart';

import 'package:nx_projects/data/projects/project_attr_keys.dart';
import 'package:nx_projects/data/tasks/task_attr_keys.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_bucket.dart';
import 'package:nx_projects/domain/task/task_kind.dart';
import 'package:nx_projects/domain/task/task_severity.dart';
import 'package:nx_projects/domain/task/task_status.dart';

Model? _firstRelated(Model m, String key) {
  final nested = m.relations?[key];
  if (nested != null && nested.isNotEmpty) return nested.first;
  return null;
}

/// [in_project] target; may include nested `Project` for subproject parent resolution.
Model? _linkedProjectModel(Model m) {
  return _firstRelated(m, kTaskProjectLinkKey);
}

Model? _linkedSprintModel(Model m) {
  return _firstRelated(m, kTaskSprintLinkKey);
}

(int? projectId, int? subProjectId) _projectIdsFromModel(Model m) {
  final linked = _linkedProjectModel(m);
  if (linked == null) return (null, null);
  final parentId = _parentProjectIdFromLinked(linked);
  if (parentId == null) {
    return (linked.id, null);
  }
  return (parentId, linked.id);
}

/// Read parent from nested [Project] row (full [Model] with relations) when available.
int? _parentProjectIdFromLinked(Model linked) {
  final nested = linked.relations?[kProjectRelationKey];
  if (nested != null) {
    for (final c in nested) {
      final a = c.attributes?['relation'];
      if (a == 'parent') return c.id;
    }
  }
  return null;
}

TaskKind _kindFromModel(Model m) {
  final n = m.modelType?.name;
  if (n == kBugModelTypeName) return TaskKind.bug;
  if (n == kFeatureModelTypeName) return TaskKind.feat;
  return TaskKind.task;
}

TaskBucket _bucketFromModel(Model m) {
  final raw = m.attrString(kTaskAttrPriority);
  if (raw == null) return TaskBucket.unsorted;
  return switch (raw) {
    'now' => TaskBucket.now,
    'next' => TaskBucket.next,
    'later' => TaskBucket.later,
    'someday' => TaskBucket.someday,
    _ => TaskBucket.unsorted,
  };
}

TaskStatus _statusFromModel(Model m) {
  final raw = m.attrString(kTaskAttrStatus);
  return switch (raw) {
    'progress' => TaskStatus.doing,
    'todo' => TaskStatus.todo,
    'done' => TaskStatus.done,
    'blocked' => TaskStatus.blocked,
    _ => TaskStatus.todo,
  };
}

TaskSeverity? _severityFromModel(Model m) {
  if (_kindFromModel(m) != TaskKind.bug) return null;
  final raw = m.attrString(kTaskAttrSeverity);
  return switch (raw) {
    'critical' => TaskSeverity.crit,
    'crit' => TaskSeverity.crit,
    'med' => TaskSeverity.med,
    'low' => TaskSeverity.low,
    'high' => TaskSeverity.med,
    _ => null,
  };
}

String? _ymdFromModel(Model m) {
  final d = m.attrDateTime(kTaskAttrDate);
  if (d == null) return null;
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

int? _relationIdForTarget(Model m, String targetType) {
  final list = m.relationsList;
  if (list == null) return null;
  for (final r in list) {
    if (r.modelType == targetType) return r.relationId;
  }
  return null;
}

Task taskFromModel(Model m) {
  final kind = _kindFromModel(m);
  final (projectId, subProjectId) = _projectIdsFromModel(m);
  final sprintM = _linkedSprintModel(m);
  final sprintId = sprintM?.id;
  return Task(
    id: m.id,
    title: m.name,
    kind: kind,
    bucket: _bucketFromModel(m),
    status: _statusFromModel(m),
    severity: _severityFromModel(m),
    projectId: projectId,
    subProjectId: subProjectId,
    crumb: _buildCrumb(m),
    estimate: m.attrDouble(kTaskAttrEstimateHours) ?? 0,
    actualHours: 0,
    sprintId: sprintId,
    plannedFor: _ymdFromModel(m),
    driftFrom: const [],
    notes: m.description?.trim() ?? '',
    inProjectRelationId: _relationIdForTarget(m, kProjectModelTypeName),
    inSprintRelationId: _relationIdForTarget(
      m,
      kTaskSprintLinkKey,
    ),
  );
}

String _buildCrumb(Model m) {
  final linked = _linkedProjectModel(m);
  if (linked == null) return '—';
  final nested = linked.relations?[kProjectRelationKey];
  if (nested != null) {
    for (final c in nested) {
      if (c.attributes?['relation'] == 'parent') {
        return '${c.name} / ${linked.name}';
      }
    }
  }
  return linked.name;
}

String _statusToDb(TaskStatus s) {
  return switch (s) {
    TaskStatus.doing => 'progress',
    _ => s.name,
  };
}

String _severityToDb(TaskSeverity s) {
  return switch (s) {
    TaskSeverity.crit => 'critical',
    _ => s.name,
  };
}

String _modelTypeNameForCreate(Task t) {
  return switch (t.kind) {
    TaskKind.bug => kBugModelTypeName,
    _ => kFeatureModelTypeName,
  };
}

int? _targetProjectIdForTask(Task t) {
  if (t.subProjectId != null) return t.subProjectId;
  return t.projectId;
}

List<SetModelAttribute> _taskAttributesForSave(Task t) {
  final attrs = <SetModelAttribute>[
    SetModelAttribute(key: kTaskAttrStatus, value: _statusToDb(t.status)),
    SetModelAttribute(key: kTaskAttrEstimateHours, value: t.estimate),
  ];
  if (t.bucket != TaskBucket.unsorted) {
    attrs.add(SetModelAttribute(key: kTaskAttrPriority, value: t.bucket.name));
  }
  final plan = t.plannedFor;
  if (plan != null && plan.isNotEmpty) {
    final p = DateTime.tryParse('${plan}T12:00:00');
    if (p != null) {
      attrs.add(SetModelAttribute(key: kTaskAttrDate, value: p.toIso8601String()));
    }
  }
  if (t.kind == TaskKind.bug && t.severity != null) {
    attrs.add(
      SetModelAttribute(key: kTaskAttrSeverity, value: _severityToDb(t.severity!)),
    );
  }
  return attrs;
}

SetModelRequest setModelRequestForCreateTask(Task t) {
  final rels = <ModelRelation>[];
  final pid = _targetProjectIdForTask(t);
  if (pid != null) {
    rels.add(
      ModelRelation(
        modelType: kTaskProjectLinkKey,
        link: [pid],
      ),
    );
  }
  if (t.sprintId != null) {
    rels.add(
      ModelRelation(
        modelType: kTaskSprintLinkKey,
        link: [t.sprintId!],
      ),
    );
  }
  return SetModelRequest(
    modelType: _modelTypeNameForCreate(t),
    name: t.title,
    description: t.notes.isEmpty ? null : t.notes,
    attributes: _taskAttributesForSave(t),
    relations: rels.isEmpty ? null : rels,
  );
}

SetModelRequest setModelRequestForUpdateTask(
  Task t,
  Model current, {
  required List<ModelRelation> relationDeltas,
}) {
  return SetModelRequest(
    id: t.id,
    modelType: current.modelType?.name,
    name: t.title,
    description: t.notes.isEmpty ? null : t.notes,
    attributes: _taskAttributesForSave(t),
    relations: relationDeltas.isEmpty ? null : relationDeltas,
  );
}

/// Fetch struct for a task model type ([Bug], [Feature], or [ProjectTask]).
///
/// Use the **concrete** subtype schema for list queries so attribute keys like
/// `severity` (Bug-only) are collected correctly by the server.
Map<String, dynamic> buildTaskFetchStruct(
  ModelType taskModelSchema,
) {
  final struct = buildKgqlStructFromSchema(taskModelSchema);
  struct[kTaskProjectLinkKey] = {
    'id': true,
    'name': true,
    'description': true,
    kProjectRelationKey: {
      'id': true,
      'name': true,
      'relation': true,
    },
  };
  struct[kTaskSprintLinkKey] = {
    'id': true,
    'name': true,
  };
  return struct;
}
