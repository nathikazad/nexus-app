import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/domain/sprint/sprint.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_status.dart';
import 'package:nx_projects/features/sprint/sprint_view_model.dart';
import 'package:nx_projects/features/sprint/widgets/desktop_day_card.dart';
import 'package:nx_projects/features/sprint/widgets/sprint_summary_strip.dart';

/// Desktop: sprint summary, plan heading, bordered day cards.
class DesktopSprintBody extends ConsumerWidget {
  const DesktopSprintBody({super.key, required this.onOpenTaskMenu});

  final void Function(BuildContext, WidgetRef, Task) onOpenTaskMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sp = ref.watch(currentSprintProvider);
    final days = ref.watch(sprintDaySlicesProvider);
    final allTasks = ref.watch(sprintTasksProvider);
    final driftN = ref.watch(sprintDriftCountProvider);
    final blockedN = ref.watch(sprintBlockedCountProvider);
    final scheduledH = allTasks
        .where((t) => t.plannedFor != null && t.plannedFor!.isNotEmpty)
        .fold<double>(0, (a, t) => a + t.estimate);
    final dailyCap = sp.length > 0 ? sp.capH / sp.length : 0.0;
    final nDone = allTasks.where((t) => t.status == TaskStatus.done).length;
    final nDoing = allTasks.where((t) => t.status == TaskStatus.doing).length;
    final nTotal = allTasks.length;
    final actualSum = allTasks.fold<double>(0, (a, t) => a + t.actualHours);
    final plannedSum = allTasks.fold<double>(0, (a, t) => a + t.estimate);
    final dayIndex = sprintDayIndexOneBased(sp);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                SprintSummaryStrip(
                  sprint: sp,
                  nDone: nDone,
                  nTotal: nTotal,
                  actualH: actualSum,
                  plannedH: plannedSum,
                  driftCount: driftN,
                  blockedCount: blockedN,
                  doingCount: nDoing,
                  dayIndex: dayIndex,
                ),
                _DaysHead(sprint: sp, scheduledH: scheduledH),
                for (final day in days)
                  DesktopDayCard(
                    slice: day,
                    sprint: sp,
                    allTasks: allTasks,
                    dailyCap: dailyCap,
                    onOpenTaskMenu: (t) => onOpenTaskMenu(context, ref, t),
                  ),
                if (allTasks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No tasks in this sprint yet.',
                        style: TextStyle(
                          color: AppColors.dim,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _DaysHead extends StatelessWidget {
  const _DaysHead({required this.sprint, required this.scheduledH});

  final Sprint sprint;
  final double scheduledH;

  String _fmt(double h) {
    if (h == h.roundToDouble()) return h.toInt().toString();
    return h.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Plan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      TextSpan(
                        text: ' · ${sprint.name}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Total: '),
                TextSpan(
                  text: '${_fmt(scheduledH)}h',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(text: ' scheduled'),
              ],
            ),
            style: const TextStyle(fontSize: 11, color: AppColors.dim),
          ),
        ],
      ),
    );
  }
}
