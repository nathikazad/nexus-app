import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_bucket.dart';
import 'package:nx_projects/features/desktop/desktop_task_drawer_state.dart';
import 'package:riverpod/riverpod.dart';

class DesktopDrawerController {
  const DesktopDrawerController(this._ref);

  final Ref _ref;

  void viewTask(int taskId) {
    _ref.read(desktopTaskDrawerProvider.notifier).viewTask(taskId);
  }

  void editTask(Task task) {
    _ref.read(desktopTaskDrawerProvider.notifier).editTask(task);
  }

  void newTask({
    int? defaultProject,
    int? defaultSub,
    TaskBucket? defaultBucket,
  }) {
    _ref
        .read(desktopTaskDrawerProvider.notifier)
        .newTask(
          defaultProject: defaultProject,
          defaultSub: defaultSub,
          defaultBucket: defaultBucket,
        );
  }

  void newProject() {
    _ref.read(desktopTaskDrawerProvider.notifier).newProject();
  }

  void newSprint() {
    _ref.read(desktopTaskDrawerProvider.notifier).newSprint();
  }

  void close() {
    _ref.read(desktopTaskDrawerProvider.notifier).close();
  }
}

final desktopDrawerControllerProvider = Provider<DesktopDrawerController>(
  DesktopDrawerController.new,
  name: 'desktopDrawerControllerProvider',
);
