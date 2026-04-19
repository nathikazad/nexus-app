import 'package:nx_db/kgql.dart';

import 'package:nx_time/core/time/wall_clock_time.dart';
import 'package:nx_time/data/projects/project_attr_keys.dart';
import 'package:nx_time/data/tasks/task_attr_keys.dart';
import 'package:nx_time/domain/tasks/task.dart';
import 'package:nx_time/domain/tasks/task_status.dart';

String? _notesDescriptionFromModel(Model model) {
  final top = model.description?.trim();
  if (top != null && top.isNotEmpty) return model.description;
  return null;
}

List<String> _tagsFromModel(Model m) {
  final raw = m.attributes?[kTaskAttrTags];
  if (raw == null) return [];
  if (raw is List) {
    return raw.map((e) => e.toString()).toList();
  }
  if (raw is String) {
    final t = raw.trim();
    if (t.isEmpty) return [];
    return [raw];
  }
  return [];
}

String? _taskEdgeRelationFromNestedModel(Model m) {
  final a = m.attributes?['relation'];
  if (a is String) return a;
  return null;
}

bool _nestedTaskNeighborIsChild(Model c) {
  final rel = _taskEdgeRelationFromNestedModel(c);
  return rel == null || rel == 'child';
}

bool _isTaskNeighborChild(Relation r) {
  if (r.modelType != kTaskRelationKey && r.modelType != kTaskModelTypeName) {
    return false;
  }
  if (r.relation == 'parent') return false;
  if (r.relation == 'child') return true;
  return r.relation == null;
}

List<int> _childTaskIdsFromModel(Model m) {
  final nested = m.relations?[kTaskRelationKey];
  if (nested != null && nested.isNotEmpty) {
    return [for (final c in nested) if (_nestedTaskNeighborIsChild(c)) c.id];
  }
  final list = m.relationsList;
  if (list == null || list.isEmpty) return [];
  return [
    for (final r in list)
      if (_isTaskNeighborChild(r)) r.modelId,
  ];
}

Map<int, int> _taskRelationIdsByChildFromModel(Model m) {
  final list = m.relationsList;
  if (list == null || list.isEmpty) return {};
  final out = <int, int>{};
  for (final r in list) {
    if (_isTaskNeighborChild(r)) {
      out[r.modelId] = r.relationId;
    }
  }
  return out;
}

int? _parentTaskIdFromModel(Model m) {
  final nested = m.relations?[kTaskRelationKey];
  if (nested != null) {
    for (final c in nested) {
      if (_taskEdgeRelationFromNestedModel(c) == 'parent') return c.id;
    }
  }
  final list = m.relationsList;
  if (list == null || list.isEmpty) return null;
  for (final r in list) {
    if ((r.modelType == kTaskRelationKey || r.modelType == kTaskModelTypeName) &&
        r.relation == 'parent') {
      return r.modelId;
    }
  }
  return null;
}

(int?, int?) _projectLinkFromModel(Model m) {
  int? projectId;
  int? projectRelationId;
  final nested = m.relations?[kProjectRelationKey];
  if (nested != null && nested.isNotEmpty) {
    projectId = nested.first.id;
  }
  final list = m.relationsList;
  if (list != null) {
    for (final r in list) {
      if (r.modelType == kProjectRelationKey) {
        projectId ??= r.modelId;
        projectRelationId = r.relationId;
        break;
      }
    }
  }
  return (projectId, projectRelationId);
}

List<TaskActivityLink> _linkedActivitiesFromModel(Model m) {
  final list = m.relationsList;
  if (list == null || list.isEmpty) return [];
  final out = <TaskActivityLink>[];
  for (final r in list) {
    if (r.modelType == kTaskRelationKey ||
        r.modelType == kTaskModelTypeName ||
        r.modelType == kProjectRelationKey) {
      continue;
    }
    out.add(
      TaskActivityLink(
        activityId: r.modelId,
        activityModelTypeName: r.modelType,
        relationId: r.relationId,
      ),
    );
  }
  return out;
}

List<SetModelAttribute> _taskAttributes(Task task) {
  final attrs = <SetModelAttribute>[
    SetModelAttribute(key: kTaskAttrStatus, value: task.status.kgqlValue),
    SetModelAttribute(key: kTaskAttrTags, value: task.tags),
  ];
  final d = task.date;
  if (d != null) {
    attrs.add(SetModelAttribute(key: kTaskAttrDate, value: d.toIso8601String()));
  }
  final st = task.startTime;
  final en = task.endTime;
  if (st != null) {
    attrs.add(
      SetModelAttribute(key: kTaskAttrStartTime, value: st.toIso8601String()),
    );
  }
  if (en != null) {
    attrs.add(
      SetModelAttribute(key: kTaskAttrEndTime, value: en.toIso8601String()),
    );
  }
  return attrs;
}

Task taskFromModel(Model m) {
  final childIds = _childTaskIdsFromModel(m);
  final statusRaw = m.attrString(kTaskAttrStatus);
  final date = m.attrDateTime(kTaskAttrDate);
  final start = m.attrDateTime(kTaskAttrStartTime);
  final end = m.attrDateTime(kTaskAttrEndTime);
  final (projectId, projectRelId) = _projectLinkFromModel(m);

  return Task(
    id: m.id,
    name: m.name,
    description: _notesDescriptionFromModel(m),
    modelTypeId: m.modelTypeId,
    modelTypeName: m.modelType?.name,
    status: taskStatusFromKgql(statusRaw),
    tags: _tagsFromModel(m),
    date: date != null ? asStoredLocalWallClock(date) : null,
    startTime: start != null ? asStoredLocalWallClock(start) : null,
    endTime: end != null ? asStoredLocalWallClock(end) : null,
    parentTaskId: _parentTaskIdFromModel(m),
    childTaskIds: childIds,
    relationIdByChildTaskId: _taskRelationIdsByChildFromModel(m),
    projectId: projectId,
    projectRelationId: projectRelId,
    linkedActivities: _linkedActivitiesFromModel(m),
  );
}

SetModelRequest setModelRequestForCreateTask(
  Task task, {
  int? parentTaskId,
  int? projectId,
}) {
  final rels = <ModelRelation>[
    if (parentTaskId != null)
      ModelRelation(
        modelType: kTaskRelationKey,
        link: [parentTaskId],
      ),
    if (projectId != null)
      ModelRelation(
        modelType: kProjectRelationKey,
        link: [projectId],
      ),
  ];

  return SetModelRequest(
    modelType: kTaskModelTypeName,
    name: task.name,
    description: task.description,
    attributes: _taskAttributes(task),
    relations: rels.isEmpty ? null : rels,
  );
}

/// When [includeAttributes] is false, only name/description (and optional model type) are sent;
/// status, tags, and times are left unchanged — avoids wiping tags on partial saves.
SetModelRequest setModelRequestForUpdateTask(
  Task task, {
  bool includeAttributes = false,
}) {
  return SetModelRequest(
    id: task.id,
    modelType: task.modelTypeName != kTaskModelTypeName ? task.modelTypeName : null,
    name: task.name,
    description: task.description,
    attributes: includeAttributes ? _taskAttributes(task) : null,
  );
}

SetModelRequest setModelRequestForDeleteTask(int id) => setKgqlDelete(id);
