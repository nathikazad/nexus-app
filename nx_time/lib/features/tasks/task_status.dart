/// Task workflow status (matches `reference/partials/view-task-detail.html` segmented control).
enum TaskStatus {
  todo,
  progress,
  done,
  skip,
}

extension TaskStatusX on TaskStatus {
  String get label {
    switch (this) {
      case TaskStatus.todo:
        return 'Todo';
      case TaskStatus.progress:
        return 'Progress';
      case TaskStatus.done:
        return 'Done';
      case TaskStatus.skip:
        return 'Skip';
    }
  }
}
