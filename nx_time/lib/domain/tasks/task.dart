import 'package:nx_time/domain/tasks/task_status.dart';
import 'package:collection/collection.dart';

class _TaskCopyUnset {
  const _TaskCopyUnset();
}

const _taskCopyUnset = _TaskCopyUnset();

/// Link from a [Task] to a concrete activity row (Action subtype) via `link_to_action`.
class TaskActivityLink {
  const TaskActivityLink({
    required this.activityId,
    required this.activityModelTypeName,
    required this.relationId,
  });

  final int activityId;
  final String activityModelTypeName;
  final int relationId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskActivityLink &&
          runtimeType == other.runtimeType &&
          activityId == other.activityId &&
          activityModelTypeName == other.activityModelTypeName &&
          relationId == other.relationId;

  @override
  int get hashCode =>
      Object.hash(activityId, activityModelTypeName, relationId);
}

/// Domain entity for a Task row in KGQL.
///
/// Pure Dart — no Flutter / nx_db.
class Task {
  const Task({
    required this.id,
    required this.name,
    this.description,
    required this.modelTypeId,
    this.modelTypeName,
    this.status = TaskStatus.todo,
    this.createdAt,
    this.dueAt,
    this.completedAt,
    this.history = const [],
    this.rank,
    this.participants = const {},
    this.parentTaskId,
    this.childTaskIds = const [],
    this.relationIdByChildTaskId = const {},
    this.projectId,
    this.projectRelationId,
    this.linkedActivities = const [],
  });

  final int id;
  final String name;
  final String? description;
  final int modelTypeId;
  final String? modelTypeName;

  final TaskStatus status;

  /// Server-managed creation timestamp.
  final DateTime? createdAt;

  /// Optional calendar pin date.
  final DateTime? dueAt;
  final DateTime? completedAt;
  final List<Map<String, dynamic>> history;
  final String? rank;
  final Map<String, dynamic> participants;

  final int? parentTaskId;

  /// Outgoing `has_subtask` children (nested `Task` on fetch).
  final List<int> childTaskIds;

  /// `relations` row id per child task id (for unlink).
  final Map<int, int> relationIdByChildTaskId;

  /// `in_project` target when set.
  final int? projectId;
  final int? projectRelationId;

  final List<TaskActivityLink> linkedActivities;

  Task copyWith({
    int? id,
    String? name,
    Object? description = _taskCopyUnset,
    int? modelTypeId,
    Object? modelTypeName = _taskCopyUnset,
    TaskStatus? status,
    Object? createdAt = _taskCopyUnset,
    Object? dueAt = _taskCopyUnset,
    Object? completedAt = _taskCopyUnset,
    List<Map<String, dynamic>>? history,
    String? rank,
    Map<String, dynamic>? participants,
    Object? parentTaskId = _taskCopyUnset,
    List<int>? childTaskIds,
    Map<int, int>? relationIdByChildTaskId,
    Object? projectId = _taskCopyUnset,
    Object? projectRelationId = _taskCopyUnset,
    List<TaskActivityLink>? linkedActivities,
  }) {
    return Task(
      id: id ?? this.id,
      name: name ?? this.name,
      description: identical(description, _taskCopyUnset)
          ? this.description
          : description as String?,
      modelTypeId: modelTypeId ?? this.modelTypeId,
      modelTypeName: identical(modelTypeName, _taskCopyUnset)
          ? this.modelTypeName
          : modelTypeName as String?,
      status: status ?? this.status,
      createdAt: identical(createdAt, _taskCopyUnset)
          ? this.createdAt
          : createdAt as DateTime?,
      dueAt: identical(dueAt, _taskCopyUnset) ? this.dueAt : dueAt as DateTime?,
      completedAt: identical(completedAt, _taskCopyUnset)
          ? this.completedAt
          : completedAt as DateTime?,
      history: history ?? this.history,
      rank: rank ?? this.rank,
      participants: participants ?? this.participants,
      parentTaskId: identical(parentTaskId, _taskCopyUnset)
          ? this.parentTaskId
          : parentTaskId as int?,
      childTaskIds: childTaskIds ?? this.childTaskIds,
      relationIdByChildTaskId:
          relationIdByChildTaskId ?? this.relationIdByChildTaskId,
      projectId: identical(projectId, _taskCopyUnset)
          ? this.projectId
          : projectId as int?,
      projectRelationId: identical(projectRelationId, _taskCopyUnset)
          ? this.projectRelationId
          : projectRelationId as int?,
      linkedActivities: linkedActivities ?? this.linkedActivities,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Task &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          modelTypeId == other.modelTypeId &&
          modelTypeName == other.modelTypeName &&
          status == other.status &&
          rank == other.rank &&
          const DeepCollectionEquality().equals(
            participants,
            other.participants,
          ) &&
          const DeepCollectionEquality().equals(history, other.history) &&
          createdAt == other.createdAt &&
          dueAt == other.dueAt &&
          completedAt == other.completedAt &&
          parentTaskId == other.parentTaskId &&
          _listEq(childTaskIds, other.childTaskIds) &&
          _mapEq(relationIdByChildTaskId, other.relationIdByChildTaskId) &&
          projectId == other.projectId &&
          projectRelationId == other.projectRelationId &&
          _listActivityEq(linkedActivities, other.linkedActivities);

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    description,
    modelTypeId,
    modelTypeName,
    status,
    rank,
    const DeepCollectionEquality().hash(participants),
    const DeepCollectionEquality().hash(history),
    createdAt,
    dueAt,
    completedAt,
    parentTaskId,
    Object.hashAll(childTaskIds),
    Object.hashAllUnordered(relationIdByChildTaskId.entries),
    projectId,
    projectRelationId,
    Object.hashAll(linkedActivities),
  ]);
}

bool _listEq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEq(Map<int, int> a, Map<int, int> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}

bool _listActivityEq(List<TaskActivityLink> a, List<TaskActivityLink> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
