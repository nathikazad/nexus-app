import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nx_projects/core/formatting/date_label.dart';
import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/core/widgets/capacity_bar.dart';
import 'package:nx_projects/domain/sprint/sprint.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_status.dart';
import 'package:nx_projects/features/shared/widgets/task_row.dart';
import 'package:nx_projects/features/sprint/sprint_view_model.dart';

/// Mobile: day-by-day sprint list with top capacity block.
class MobileSprintBody extends ConsumerWidget {
  const MobileSprintBody({super.key, required this.onOpenTaskMenu});

  final void Function(BuildContext, WidgetRef, Task) onOpenTaskMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sp = ref.watch(currentSprintProvider);
    final stats = ref.watch(sprintHeaderStatsProvider);
    final days = ref.watch(sprintDaySlicesProvider);
    final allTasks = ref.watch(sprintTasksProvider);
    final unscheduled =
        allTasks.where((t) => t.plannedFor == null || t.plannedFor!.isEmpty).toList();
    final dailyCap = sp.length > 0 ? sp.capH / sp.length : 0.0;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _CapBlock(stats: stats, sprint: sp),
        for (final day in days) ...[
          _DayHead(
            ymd: day.ymd,
            tasks: day.tasks,
            dailyCap: dailyCap,
            isToday: day.isToday,
          ),
          if (day.tasks.isNotEmpty)
            ...day.tasks.map(
              (t) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: TaskRow(
                  task: t,
                  showStatus: true,
                  onMenu: () => onOpenTaskMenu(context, ref, t),
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                'Nothing planned',
                style: TextStyle(color: AppColors.dim, fontStyle: FontStyle.italic, fontSize: 13),
              ),
            ),
        ],
        if (unscheduled.isNotEmpty) ...[
          _SectionHeader(title: 'UNSCHEDULED', count: unscheduled.length),
          ...unscheduled.map(
            (t) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: TaskRow(
                task: t,
                showStatus: true,
                onMenu: () => onOpenTaskMenu(context, ref, t),
              ),
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
      ],
    );
  }
}

class _CapBlock extends StatelessWidget {
  const _CapBlock({required this.stats, required this.sprint});

  final SprintHeaderStats stats;
  final Sprint sprint;

  @override
  Widget build(BuildContext context) {
    final totalLabel = stats.totalH == stats.totalH.roundToDouble()
        ? '${stats.totalH.toInt()}'
        : '${stats.totalH}';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Planned', style: TextStyle(fontSize: 12, color: AppColors.muted)),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${totalLabel}h',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    TextSpan(
                      text: ' / ${sprint.capH.toInt()}h  ',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    TextSpan(
                      text: '${stats.pct}%',
                      style: const TextStyle(fontSize: 11, color: AppColors.dim),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CapacityBar(
            todoH: stats.todoH,
            doingH: stats.doingH,
            blockedH: stats.blockedH,
            doneH: stats.doneH,
            capH: sprint.capH,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (stats.nDoing > 0) _Chip(label: '${stats.nDoing} doing', color: AppColors.accent, soft: true),
              if (stats.nTodo > 0) _Chip(label: '${stats.nTodo} todo', color: AppColors.muted, soft: false),
              if (stats.nBlocked > 0) _Chip(label: '${stats.nBlocked} blocked', color: AppColors.warn, soft: true),
              if (stats.nDone > 0) _Chip(label: '${stats.nDone} done', color: AppColors.ok, soft: true),
              if (stats.nFeat > 0) _Chip(label: '◉ ${stats.nFeat} feat', color: AppColors.feat, soft: true),
              if (stats.nBug > 0)
                _Chip(
                  label: '● ${stats.nBug} bug${stats.critBugs > 0 ? ' · ${stats.critBugs} crit' : ''}',
                  color: AppColors.bug,
                  soft: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, required this.soft});

  final String label;
  final Color color;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: soft ? color.withValues(alpha: 0.12) : AppColors.panel2,
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color == AppColors.muted ? AppColors.muted : color,
        ),
      ),
    );
  }
}

class _DayHead extends StatelessWidget {
  const _DayHead({
    required this.ymd,
    required this.tasks,
    required this.dailyCap,
    required this.isToday,
  });

  final String ymd;
  final List<Task> tasks;
  final double dailyCap;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final d = parseLocalDate(ymd);
    final nDone = tasks.where((t) => t.status == TaskStatus.done).length;
    final dayH = tasks.fold<double>(0, (a, t) => a + t.estimate);
    final meta = tasks.isEmpty
        ? '0'
        : '${tasks.length} · $nDone/${tasks.length} done';
    final capLine = dailyCap > 0 ? '$meta · ${dayH.toStringAsFixed(0)}/${dailyCap.toStringAsFixed(0)}h' : meta;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(6, 18, 6, 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isToday ? AppColors.accent : AppColors.border,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                shortDowLabel(d).toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: isToday ? AppColors.accent : AppColors.text,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                DateFormat('MMM d').format(d),
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'TODAY',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: AppColors.bg,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                capLine,
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.4,
                  color: AppColors.dim,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
          child: DayCapBar(
            ratio: dailyCap > 0 ? (dayH / dailyCap) : 0,
            isOver: dailyCap > 0 && dayH > dailyCap,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.panel2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count', style: const TextStyle(fontSize: 10, color: AppColors.muted)),
          ),
        ],
      ),
    );
  }
}
