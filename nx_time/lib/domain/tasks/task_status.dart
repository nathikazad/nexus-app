/// Stored in KGQL attribute `status` (lowercase string).
enum TaskStatus { todo, progress, done, skip }

extension TaskStatusKgql on TaskStatus {
  /// Value persisted in `attribute_definitions.key == status`.
  String get kgqlValue => name;
}

/// Parses [raw] from KGQL; defaults to [TaskStatus.todo] when missing/unknown.
TaskStatus taskStatusFromKgql(String? raw) {
  if (raw == null || raw.isEmpty) return TaskStatus.todo;
  switch (raw.trim().toLowerCase()) {
    case 'todo':
      return TaskStatus.todo;
    case 'progress':
    case 'in_progress':
      return TaskStatus.progress;
    case 'done':
    case 'completed':
      return TaskStatus.done;
    case 'skip':
    case 'skipped':
      return TaskStatus.skip;
    default:
      return TaskStatus.todo;
  }
}
