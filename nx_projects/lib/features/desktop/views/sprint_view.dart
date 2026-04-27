import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/features/desktop/desktop_task_drawer_state.dart';
import 'package:nx_projects/features/desktop/widgets/desktop_drawer_layer.dart';
import 'package:nx_projects/features/desktop/widgets/sprint_cart.dart';
import 'package:nx_projects/features/shared/widgets/context_sheet.dart';
import 'package:nx_projects/features/shell/selection_providers.dart';
import 'package:nx_projects/features/sprint/sprint_screen.dart';

/// Desktop Sprint: cart on the left + day list (reference `.body.sprint-plan-body`).
class DesktopSprintView extends ConsumerWidget {
  const DesktopSprintView({super.key});

  void _openTaskMenu(BuildContext context, WidgetRef ref, Task t) {
    showTaskContextSheet(context, ref, task: t, onAfterChange: () {});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drawerOpen =
        ref.watch(desktopTaskDrawerProvider) is! DesktopTaskDrawerClosed;

    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SprintCart(
              border: SprintCartBorder.right,
              surface: SprintCartSurface.sprint,
              onFooter: () {
                ref.read(desktopViewIndexProvider.notifier).setView(0);
              },
            ),
            Expanded(child: SprintScreen(onOpenTaskMenu: _openTaskMenu)),
          ],
        ),
        if (drawerOpen) const Positioned.fill(child: DesktopDrawerLayer()),
      ],
    );
  }
}
