import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_bucket.dart';
import 'package:riverpod/riverpod.dart';

/// Desktop-only overlay state: task view, task create/edit, or project create in the
/// right-side panel ([ReferenceSideDrawer]).
sealed class DesktopTaskDrawerState {
  const DesktopTaskDrawerState();
}

class DesktopTaskDrawerClosed extends DesktopTaskDrawerState {
  const DesktopTaskDrawerClosed();
}

class DesktopTaskViewing extends DesktopTaskDrawerState {
  const DesktopTaskViewing(this.taskId);
  final int taskId;
}

class DesktopTaskEditing extends DesktopTaskDrawerState {
  const DesktopTaskEditing(this.task);
  final Task task;
}

class DesktopTaskCreating extends DesktopTaskDrawerState {
  const DesktopTaskCreating({
    this.defaultProject,
    this.defaultSub,
    this.defaultBucket,
  });
  final int? defaultProject;
  final int? defaultSub;
  final TaskBucket? defaultBucket;
}

class DesktopProjectCreating extends DesktopTaskDrawerState {
  const DesktopProjectCreating();
}

class DesktopTaskDrawer extends Notifier<DesktopTaskDrawerState> {
  @override
  DesktopTaskDrawerState build() => const DesktopTaskDrawerClosed();

  void viewTask(int taskId) {
    state = DesktopTaskViewing(taskId);
  }

  void editTask(Task task) {
    state = DesktopTaskEditing(task);
  }

  void newTask({int? defaultProject, int? defaultSub, TaskBucket? defaultBucket}) {
    state = DesktopTaskCreating(
      defaultProject: defaultProject,
      defaultSub: defaultSub,
      defaultBucket: defaultBucket,
    );
  }

  void newProject() {
    state = const DesktopProjectCreating();
  }

  void close() {
    state = const DesktopTaskDrawerClosed();
  }
}

final desktopTaskDrawerProvider =
    NotifierProvider<DesktopTaskDrawer, DesktopTaskDrawerState>(
  DesktopTaskDrawer.new,
  name: 'desktopTaskDrawerProvider',
);
