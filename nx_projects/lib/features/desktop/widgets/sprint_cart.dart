import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';

import 'package:nx_projects/core/formatting/date_label.dart';
import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/core/theme/kind_color_palette.dart';
import 'package:nx_projects/data/providers.dart';
import 'package:nx_projects/domain/project/project.dart';
import 'package:nx_projects/domain/sprint/sprint.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_kind.dart';
import 'package:nx_projects/features/desktop/desktop_drawer_controller.dart';
import 'package:nx_projects/features/desktop/desktop_task_locator.dart';
import 'package:nx_projects/features/shell/selection_providers.dart';
import 'package:nx_projects/features/sprint/sprint_view_model.dart';

part 'sprint_cart_parts/sprint_cart_header.dart';
part 'sprint_cart_parts/sprint_cart_body.dart';
part 'sprint_cart_parts/sprint_goal_field.dart';
part 'sprint_cart_parts/sprint_cart_task_row.dart';
part 'sprint_cart_parts/sprint_cart_footer.dart';

/// Which edge has the 1px separator toward the main content.
enum SprintCartBorder {
  /// Cart is on the right (Planner): border on the left of the cart.
  left,

  /// Cart is on the left (Sprint): border on the right of the cart.
  right,
}

/// Whether the cart is shown beside Planner (backlog) or beside Sprint (day plan).
enum SprintCartSurface {
  /// Unpin (×) on each row; no unscheduled day indicator; footer → Sprint.
  planner,

  /// Unscheduled day indicator in the trailing column instead of ×; footer → Planner.
  sprint,
}

/// `reference/desktop/partials/panel-sprint-cart.html` — sprint nav, dots, capacity, list, footer.
class SprintCart extends ConsumerWidget {
  SprintCart({
    super.key,
    required this.border,
    required this.surface,
    required this.onFooter,
  });

  final SprintCartBorder border;
  final SprintCartSurface surface;
  final VoidCallback onFooter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sprints = ref.watch(sprintsListProvider);
    final idx = ref.watch(sprintIndexProvider);
    if (sprints.isEmpty) {
      return SizedBox.shrink();
    }
    final sp = idx >= 0 && idx < sprints.length
        ? sprints[idx]
        : sprints[sprints.length > 1 ? 1 : 0];
    final stats = ref.watch(sprintHeaderStatsProvider);
    final tasks = ref.watch(sprintTasksProvider);
    final projects = ref.watch(projectsListProvider);

    final box = BoxDecoration(
      color: context.colors.panel,
      border: border == SprintCartBorder.left
          ? Border(left: BorderSide(color: context.colors.border))
          : Border(right: BorderSide(color: context.colors.border)),
    );

    return Container(
      width: 340,
      decoration: box,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SprintNavStrip(
            sp: sp,
            sprintIdx: idx,
            sprints: sprints,
            onPrev: () {
              if (idx > 0) ref.read(sprintIndexProvider.notifier).set(idx - 1);
            },
            onNext: () {
              if (idx < sprints.length - 1) {
                ref.read(sprintIndexProvider.notifier).set(idx + 1);
              }
            },
          ),
          _SprintDots(
            sprints: sprints,
            currentIdx: idx,
            onPick: (i) => ref.read(sprintIndexProvider.notifier).set(i),
            onAdd: () => ref.read(desktopDrawerControllerProvider).newSprint(),
          ),
          _CapBlock(stats: stats, sprint: sp),
          Expanded(
            child: _CartBody(
              sprint: sp,
              tasks: tasks,
              projects: projects,
              surface: surface,
            ),
          ),
          _CartFooter(surface: surface, onPressed: onFooter),
        ],
      ),
    );
  }
}
