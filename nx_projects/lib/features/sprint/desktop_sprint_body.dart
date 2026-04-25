import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/domain/sprint/sprint.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/features/sprint/sprint_view_model.dart';
import 'package:nx_projects/features/sprint/widgets/desktop_day_card.dart';
import 'package:nx_projects/features/sprint/widgets/sprint_summary_strip.dart';
import 'package:nx_projects/features/sprint/widgets/day_item_row.dart';

/// Desktop: sprint summary, plan heading, bordered day cards.
/// Card-to-card drag-and-drop is not implemented — see `DayItemRow` / empty-day hint.
class DesktopSprintBody extends ConsumerWidget {
  const DesktopSprintBody({super.key, required this.onOpenTaskMenu});

  final void Function(BuildContext, WidgetRef, Task) onOpenTaskMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sp = ref.watch(currentSprintProvider);
    final stats = ref.watch(sprintHeaderStatsProvider);
    final days = ref.watch(sprintDaySlicesProvider);
    final allTasks = ref.watch(sprintTasksProvider);
    final unscheduled =
        allTasks.where((t) => t.plannedFor == null || t.plannedFor!.isEmpty).toList();
    final unscheduledH = unscheduled.fold<double>(0, (a, t) => a + t.estimate);
    final scheduledH = allTasks
        .where((t) => t.plannedFor != null && t.plannedFor!.isNotEmpty)
        .fold<double>(0, (a, t) => a + t.estimate);
    final dailyCap = sp.length > 0 ? sp.capH / sp.length : 0.0;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 24, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              SprintSummaryStrip(
                sprint: sp,
                stats: stats,
                scheduledH: scheduledH,
                unscheduledH: unscheduledH,
              ),
              _DaysHead(sprint: sp),
              for (final day in days)
                DesktopDayCard(
                  slice: day,
                  dailyCap: dailyCap,
                  onOpenTaskMenu: (t) => onOpenTaskMenu(context, ref, t),
                ),
              if (unscheduled.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(2, 8, 2, 6),
                  child: Text(
                    'UNSCHEDULED',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.dim,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                for (final t in unscheduled)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: DayItemRow(
                      task: t,
                      onMenu: () => onOpenTaskMenu(context, ref, t),
                    ),
                  ),
              ],
              if (allTasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No tasks in this sprint yet.',
                      style: TextStyle(color: AppColors.dim, fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _DaysHead extends StatelessWidget {
  const _DaysHead({required this.sprint});

  final Sprint sprint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan  ·  ${sprint.name}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Drag items from the cart onto a day. Drag between days to reshuffle — not wired in Flutter yet.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'See legend in sprint cart',
            style: TextStyle(fontSize: 11, color: AppColors.dim),
          ),
        ],
      ),
    );
  }
}
