import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/data/providers.dart';
import 'package:nx_projects/domain/project/project.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/features/desktop/desktop_drawer_controller.dart';
import 'package:nx_projects/features/desktop/desktop_navigation_controller.dart';
import 'package:nx_projects/features/desktop/widgets/sprint_cart.dart';
import 'package:nx_projects/features/filters/filter_state_providers.dart';
import 'package:nx_projects/features/priority/priority_screen.dart';
import 'package:nx_projects/features/projects/projects_screen.dart';
import 'package:nx_projects/features/desktop/desktop_task_drawer_state.dart';
import 'package:nx_projects/features/desktop/widgets/desktop_drawer_layer.dart';
import 'package:nx_projects/features/shell/selection_providers.dart';
import 'package:nx_projects/features/shared/widgets/context_sheet.dart';

part 'planner_parts/planner_left_pane.dart';
part 'planner_parts/planner_add_menu.dart';
part 'planner_parts/planner_filter_bar.dart';

/// `reference/desktop/` Planner: left backlog + right sprint cart.
class PlannerView extends ConsumerWidget {
  const PlannerView({super.key});

  void _openTaskMenu(BuildContext context, WidgetRef ref, Task t) {
    showTaskContextSheet(context, ref, task: t, onAfterChange: () {});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void goSprint() {
      ref.read(desktopNavigationControllerProvider).showSprint();
    }

    final drawerOpen =
        ref.watch(desktopTaskDrawerProvider) is! DesktopTaskDrawerClosed;

    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _PlannerLeftPane(
                onOpenTaskMenu: _openTaskMenu,
                onNewProject: () {
                  ref.read(desktopDrawerControllerProvider).newProject();
                },
                onNewSprint: () {
                  ref.read(desktopDrawerControllerProvider).newSprint();
                },
                onNewTask: () {
                  ref
                      .read(desktopDrawerControllerProvider)
                      .newTask(
                        defaultProject: ref.read(selectedProjectIdProvider),
                        defaultSub: ref.read(selectedSubProjectIdProvider),
                      );
                },
              ),
            ),
            SprintCart(
              border: SprintCartBorder.left,
              surface: SprintCartSurface.planner,
              onFooter: goSprint,
            ),
          ],
        ),
        if (drawerOpen) const Positioned.fill(child: DesktopDrawerLayer()),
      ],
    );
  }
}
