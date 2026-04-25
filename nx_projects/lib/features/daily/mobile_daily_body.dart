import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/layout/layout.dart';
import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/core/widgets/capacity_bar.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/features/daily/daily_view_model.dart';
import 'package:nx_projects/features/shared/widgets/task_row.dart';

/// Mobile: single-column daily task list.
class MobileDailyBody extends ConsumerWidget {
  const MobileDailyBody({super.key, required this.onOpenTaskMenu});

  final void Function(BuildContext, WidgetRef, Task) onOpenTaskMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(dailyTasksProvider);
    final stats = ref.watch(dailyHeaderStatsProvider);

    if (tasks.isEmpty) {
      return const Center(
        child: Text(
          'Nothing planned for this day.',
          style: TextStyle(color: AppColors.dim, fontStyle: FontStyle.italic),
        ),
      );
    }

    return ListView(
      padding: NxLayout.contentPadding,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
          child: Text(
            '${tasks.length} task${tasks.length == 1 ? '' : 's'} · ${stats.totalEst.toStringAsFixed(0)}h planned',
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ),
        _DailySummary(stats: stats),
        for (final t in tasks)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TaskRow(
              task: t,
              showStatus: true,
              onMenu: () => onOpenTaskMenu(context, ref, t),
            ),
          ),
      ],
    );
  }
}

class _DailySummary extends StatelessWidget {
  const _DailySummary({required this.stats});

  final DailyHeaderStats stats;

  @override
  Widget build(BuildContext context) {
    final left = stats.hTodo + stats.hBlocked + stats.hDoing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DailyProgressBar(
            todoH: stats.hTodo,
            doingH: stats.hDoing,
            blockedH: stats.hBlocked,
            doneH: stats.hDone,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${stats.hDone.toStringAsFixed(0)}h done',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
              Text(
                '${stats.pct}%',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
              Text(
                '${left.toStringAsFixed(0)}h left',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
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
          const SizedBox(height: 8),
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
