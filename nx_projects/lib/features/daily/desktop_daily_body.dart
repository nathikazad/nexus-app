import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/core/formatting/date_label.dart';
import 'package:nx_projects/core/theme/app_theme.dart';
import 'package:nx_projects/core/widgets/capacity_bar.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/features/daily/daily_view_model.dart';
import 'package:nx_projects/features/daily/widgets/actions_zone_placeholder.dart';
import 'package:nx_projects/features/daily/widgets/dd_head.dart';
import 'package:nx_projects/features/daily/widgets/dd_journal.dart';
import 'package:nx_projects/features/daily/widgets/dd_stats.dart';
import 'package:nx_projects/features/daily/widgets/dd_task_row.dart';
import 'package:nx_projects/features/shell/selection_providers.dart';

/// Desktop two-column day page + journal (`reference/desktop` `view-today` layout, simplified).
class DesktopDailyBody extends ConsumerWidget {
  const DesktopDailyBody({super.key, required this.onOpenTaskMenu});

  final void Function(BuildContext, WidgetRef, Task) onOpenTaskMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ymd = ref.watch(dailyDateProvider);
    final dailyDate = parseLocalDate(ymd);
    final tasks = ref.watch(dailyTasksProvider);
    final stats = ref.watch(dailyHeaderStatsProvider);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              DdHead(
                dailyDate: dailyDate,
                onPrev: () {
                  final d = dailyDate.subtract(const Duration(days: 1));
                  ref.read(dailyDateProvider.notifier).set(formatYmd(d));
                },
                onNext: () {
                  final d = dailyDate.add(const Duration(days: 1));
                  ref.read(dailyDateProvider.notifier).set(formatYmd(d));
                },
              ),
              const SizedBox(height: 12),
              DdStats(stats: stats),
              const SizedBox(height: 12),
              DailyProgressBar(
                todoH: stats.hTodo,
                doingH: stats.hDoing,
                blockedH: stats.hBlocked,
                doneH: stats.hDone,
              ),
              const SizedBox(height: 20),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 60,
                      child: _TasksColumn(
                        tasks: tasks,
                        onOpenTaskMenu: onOpenTaskMenu,
                      ),
                    ),
                    const SizedBox(width: 24),
                    const Expanded(
                      flex: 40,
                      child: ActionsZonePlaceholder(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const DdJournal(),
            ]),
          ),
        ),
      ],
    );
  }
}

class _TasksColumn extends ConsumerWidget {
  const _TasksColumn({
    required this.tasks,
    required this.onOpenTaskMenu,
  });

  final List<Task> tasks;
  final void Function(BuildContext, WidgetRef, Task) onOpenTaskMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'TASKS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.muted,
              ),
            ),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: 12),
                child: Divider(color: AppColors.border, height: 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (tasks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Nothing planned for this day.',
              style: TextStyle(color: AppColors.dim, fontStyle: FontStyle.italic, fontSize: 13),
            ),
          )
        else
          ...tasks.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DdTaskRow(
                task: t,
                onMenu: () => onOpenTaskMenu(context, ref, t),
              ),
            ),
          ),
      ],
    );
  }
}
