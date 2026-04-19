import 'package:nx_time/domain/tasks/task_status.dart';

export 'package:nx_time/domain/tasks/task_status.dart';

/// UI labels for [TaskStatus] (matches reference segmented control).
extension TaskStatusLabel on TaskStatus {
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
