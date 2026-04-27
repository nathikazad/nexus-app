import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/features/desktop/desktop_task_drawer_state.dart';
import 'package:nx_projects/features/desktop/widgets/reference_side_drawer.dart';
import 'package:nx_projects/features/sprint/sprint_edit_panel.dart';
import 'package:nx_projects/features/task_edit/project_edit_sheet.dart';
import 'package:nx_projects/features/task_edit/task_edit_sheet.dart';
import 'package:nx_projects/features/task_view/task_view_drawer.dart';

class DesktopDrawerLayer extends ConsumerWidget {
  const DesktopDrawerLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(desktopTaskDrawerProvider);
    void close() => ref.read(desktopTaskDrawerProvider.notifier).close();

    return switch (s) {
      DesktopTaskDrawerClosed() => const SizedBox.shrink(),
      DesktopTaskViewing(:final taskId) => ReferenceSideDrawer(
        onClose: close,
        showHeader: false,
        widthMode: ReferenceSideDrawerWidth.wide,
        child: TaskViewDrawerContent(taskId: taskId, onClose: close),
      ),
      DesktopTaskEditing(:final task) => ReferenceSideDrawer(
        onClose: close,
        title: 'Edit task',
        widthMode: ReferenceSideDrawerWidth.narrow,
        child: TaskEditForm(
          key: ValueKey<Object>('e-${task.id}'),
          useReferenceDialog: false,
          sidePanel: true,
          onSidePanelClose: close,
          task: task,
          onSave: () {},
        ),
      ),
      DesktopTaskCreating(
        :final defaultProject,
        :final defaultSub,
        :final defaultBucket,
      ) =>
        ReferenceSideDrawer(
          onClose: close,
          title: 'New task',
          widthMode: ReferenceSideDrawerWidth.narrow,
          child: TaskEditForm(
            key: ObjectKey('new-$defaultProject-$defaultSub-$defaultBucket'),
            useReferenceDialog: false,
            sidePanel: true,
            onSidePanelClose: close,
            task: null,
            defaultProject: defaultProject,
            defaultSub: defaultSub,
            defaultBucket: defaultBucket,
            onSave: () {},
          ),
        ),
      DesktopProjectCreating() => ReferenceSideDrawer(
        onClose: close,
        title: 'New project',
        widthMode: ReferenceSideDrawerWidth.narrow,
        child: ProjectEditForm(
          useReferenceDialog: false,
          sidePanel: true,
          onSidePanelClose: close,
          onSave: () {},
        ),
      ),
      DesktopSprintCreating() => ReferenceSideDrawer(
        onClose: close,
        title: 'New sprint',
        subtitle: 'Create a desktop planning sprint',
        widthMode: ReferenceSideDrawerWidth.narrow,
        child: SprintCreatePanel(onClose: close),
      ),
    };
  }
}
