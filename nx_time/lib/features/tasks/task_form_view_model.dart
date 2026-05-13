import 'package:nx_time/domain/tasks/task.dart';
import 'package:nx_time/domain/tasks/task_status.dart';

/// Mutable draft for create / edit forms (not persisted until save).
class TaskDraft {
  TaskDraft({
    this.name = '',
    this.status = TaskStatus.todo,
    List<String>? tags,
    this.notes,
    this.date,
    this.startTime,
    this.endTime,
    this.projectId,
  }) : tags = List<String>.from(tags ?? const []);

  String name;
  TaskStatus status;
  List<String> tags;
  String? notes;
  DateTime? date;
  DateTime? startTime;
  DateTime? endTime;
  int? projectId;

  factory TaskDraft.fromTask(Task t) {
    return TaskDraft(
      name: t.name,
      status: t.status,
      tags: List<String>.from(t.tags),
      notes: t.description,
      date: t.date,
      startTime: t.startTime,
      endTime: t.endTime,
      projectId: t.projectId,
    );
  }

  bool get canSave => name.trim().isNotEmpty;

  /// New row payload (id must be filled by repo).
  Task toTaskForCreate({required int modelTypeId, String? modelTypeName}) {
    final n = name.trim();
    final note = notes?.trim();
    return Task(
      id: 0,
      name: n,
      description: (note == null || note.isEmpty) ? null : note,
      modelTypeId: modelTypeId,
      modelTypeName: modelTypeName,
      status: status,
      tags: List<String>.from(tags),
      date: date,
      startTime: startTime,
      endTime: endTime,
    );
  }

  /// Merge draft into [initial] for `TaskRepository.update(..., includeAttributes: true)`.
  Task toTaskUpdate(Task initial) {
    final n = name.trim();
    final note = notes?.trim();
    return initial.copyWith(
      name: n,
      description: (note == null || note.isEmpty) ? null : note,
      status: status,
      tags: List<String>.from(tags),
      date: date,
      startTime: startTime,
      endTime: endTime,
    );
  }
}
