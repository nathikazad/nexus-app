import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/domain/sprint/sprint.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_status.dart';
import 'package:nx_projects/features/sprint/sprint_view_model.dart';
import 'package:nx_projects/features/sprint/widgets/desktop_day_card.dart';
import 'package:nx_projects/features/sprint/widgets/sprint_summary_strip.dart';
import 'package:nx_projects/features/sprint/widgets/day_item_row.dart';

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
    final unscheduled =
        allTasks.where((t) => t.plannedFor == null || t.plannedFor!.isEmpty).toList();
    final unscheduledH = unscheduled.fold<double>(0, (a, t) => a + t.estimate);
    final scheduledH = allTasks
        .where((t) => t.plannedFor != null && t.plannedFor!.isNotEmpty)
        .fold<double>(0, (a, t) => a + t.estimate);
    final dailyCap = sp.length > 0 ? sp.capH / sp.length : 0.0;
    final nDone = allTasks.where((t) => t.status == TaskStatus.done).length;
    final nTotal = allTasks.length;
    final actualSum = allTasks.fold<double>(0, (a, t) => a + t.actualHours);
    final plannedSum = allTasks.fold<double>(0, (a, t) => a + t.estimate);

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
                ),
                _DaysHead(
                  sprint: sp,
                  scheduledH: scheduledH,
                  unscheduledH: unscheduledH,
                ),
                for (final day in days)
                  DesktopDayCard(
                    slice: day,
                    sprint: sp,
                    allTasks: allTasks,
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
      ),
    );
  }
}

class _DaysHead extends StatelessWidget {
  const _DaysHead({
    required this.sprint,
    required this.scheduledH,
    required this.unscheduledH,
  });

  final Sprint sprint;
  final double scheduledH;
  final double unscheduledH;

  String _fmt(double h) {
    if (h == h.roundToDouble()) return h.toInt().toString();
    return h.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final k = sprintDayIndexOneBased(sprint);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                'Plan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const Spacer(),
              Text(
                '${sprint.name} · Day $k of ${sprint.length}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _LegendChip(
                color: AppColors.accent,
                text: 'Scheduled · ${_fmt(scheduledH)}h',
              ),
              _LegendChip(
                color: unscheduledH > 0 ? AppColors.warn : AppColors.dim,
                text: 'Unsched · ${_fmt(unscheduledH)}h',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 11, color: AppColors.dim),
        ),
      ],
    );
  }
}
