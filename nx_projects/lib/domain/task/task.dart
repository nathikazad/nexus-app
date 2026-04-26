import 'package:nx_projects/domain/task/task_bucket.dart';
import 'package:nx_projects/domain/task/task_kind.dart';
import 'package:nx_projects/domain/task/task_severity.dart';
import 'package:nx_projects/domain/task/task_status.dart';

class Task {
  const Task({
    required this.id,
    required this.title,
    this.kind = TaskKind.feat,
    this.bucket = TaskBucket.next,
    this.status = TaskStatus.todo,
    this.severity,
    this.projectId,
    this.subProjectId,
    this.crumb = '',
    this.estimate = 0,
    this.actualHours = 0,
    this.sprintId,
    this.plannedFor,
    this.driftFrom = const [],
    this.notes = '',
    this.inProjectRelationId,
    this.inSprintRelationId,
  });

  final int id;
  final String title;
  final TaskKind kind;
  final TaskBucket bucket;
  final TaskStatus status;
  final TaskSeverity? severity;
  final int? projectId;
  final int? subProjectId;
  final String crumb;
  final double estimate;
  /// Logged or recorded actual hours (simulated in fake data).
  final double actualHours;
  final int? sprintId;
  /// YYYY-MM-DD
  final String? plannedFor;
  /// Past `plannedFor` YMDs when the task was moved to another day.
  final List<String> driftFrom;
  final String notes;

  /// KGQL `in_project` relation row id when read from the server (for unlink updates).
  final int? inProjectRelationId;

  /// KGQL `in_sprint` relation row id when read from the server (for unlink updates).
  final int? inSprintRelationId;

  Task copyWith({
    int? id,
    String? title,
    TaskKind? kind,
    TaskBucket? bucket,
    TaskStatus? status,
    TaskSeverity? severity,
    bool clearSeverity = false,
    int? projectId,
    int? subProjectId,
    bool clearSubProject = false,
    String? crumb,
    double? estimate,
    double? actualHours,
    int? sprintId,
    String? plannedFor,
    bool clearSprint = false,
    bool clearPlannedFor = false,
    List<String>? driftFrom,
    bool clearDrift = false,
    String? notes,
    int? inProjectRelationId,
    int? inSprintRelationId,
    bool clearInProjectRelationId = false,
    bool clearInSprintRelationId = false,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      bucket: bucket ?? this.bucket,
      status: status ?? this.status,
      severity: clearSeverity ? null : (severity ?? this.severity),
      projectId: projectId ?? this.projectId,
      subProjectId: clearSubProject
          ? null
          : (subProjectId ?? this.subProjectId),
      crumb: crumb ?? this.crumb,
      estimate: estimate ?? this.estimate,
      actualHours: actualHours ?? this.actualHours,
      sprintId: clearSprint ? null : (sprintId ?? this.sprintId),
      plannedFor: clearSprint || clearPlannedFor
          ? null
          : (plannedFor ?? this.plannedFor),
      driftFrom: clearSprint || clearDrift
          ? const <String>[]
          : (driftFrom ?? this.driftFrom),
      notes: notes ?? this.notes,
      inProjectRelationId: clearInProjectRelationId
          ? null
          : (inProjectRelationId ?? this.inProjectRelationId),
      inSprintRelationId: clearInSprintRelationId
          ? null
          : (inSprintRelationId ?? this.inSprintRelationId),
    );
  }
}
