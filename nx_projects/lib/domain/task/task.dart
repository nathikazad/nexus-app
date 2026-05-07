import 'package:nx_projects/domain/task/ideation_status.dart';
import 'package:nx_projects/domain/task/task_bucket.dart';
import 'package:nx_projects/domain/task/task_kind.dart';
import 'package:nx_projects/domain/task/task_severity.dart';
import 'package:nx_projects/domain/task/task_status.dart';

class TaskWorkLink {
  const TaskWorkLink({
    required this.relationId,
    required this.workActionId,
    required this.workActionName,
    this.startTime,
    this.endTime,
    this.relationStartTime,
    this.relationEndTime,
    this.workDescription = '',
    this.timeSpentHours,
  });

  final int relationId;
  final int workActionId;
  final String workActionName;

  /// Display time: relation override when present, otherwise the linked Work action time.
  final DateTime? startTime;
  final DateTime? endTime;

  /// Editable Task -> Work relation attributes. Null means the relation has no override.
  final DateTime? relationStartTime;
  final DateTime? relationEndTime;
  final String workDescription;
  final double? timeSpentHours;
}

class WorkActionOption {
  const WorkActionOption({
    required this.id,
    required this.name,
    this.startTime,
    this.endTime,
  });

  final int id;
  final String name;
  final DateTime? startTime;
  final DateTime? endTime;
}

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
    this.ideationStatus,
    this.workLinks = const [],
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

  /// [Feature] only: `ideation_status` in the database.
  final IdeationStatus? ideationStatus;

  /// ProjectTask -> Work links with relation attributes.
  final List<TaskWorkLink> workLinks;

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
    IdeationStatus? ideationStatus,
    bool clearIdeationStatus = false,
    List<TaskWorkLink>? workLinks,
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
      ideationStatus: clearIdeationStatus
          ? null
          : (ideationStatus ?? this.ideationStatus),
      workLinks: workLinks ?? this.workLinks,
    );
  }
}
