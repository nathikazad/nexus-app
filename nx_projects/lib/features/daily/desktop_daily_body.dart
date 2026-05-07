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
  DesktopDailyBody({
    super.key,
    required this.onOpenTaskMenu,
    required this.onOpenTask,
  });

  final void Function(BuildContext, WidgetRef, Task) onOpenTaskMenu;
  final void Function(BuildContext, WidgetRef, Task) onOpenTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ymd = ref.watch(dailyDateProvider);
    final dailyDate = parseLocalDate(ymd);
    final tasks = ref.watch(dailyTasksProvider);
    final stats = ref.watch(dailyHeaderStatsProvider);
    final actions = ref.watch(dailyWorkActionsAsyncProvider);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              DdHead(
                dailyDate: dailyDate,
                onPrev: () {
                  final d = dailyDate.subtract(Duration(days: 1));
                  ref.read(dailyDateProvider.notifier).set(formatYmd(d));
                },
                onNext: () {
                  final d = dailyDate.add(Duration(days: 1));
                  ref.read(dailyDateProvider.notifier).set(formatYmd(d));
                },
              ),
              SizedBox(height: 12),
              DdStats(stats: stats),
              SizedBox(height: 12),
              DailyProgressBar(
                todoH: stats.hTodo,
                doingH: stats.hDoing,
                blockedH: stats.hBlocked,
                doneH: stats.hDone,
              ),
              SizedBox(height: 20),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 60,
                      child: _TasksColumn(
                        tasks: tasks,
                        onOpenTaskMenu: onOpenTaskMenu,
                        onOpenTask: onOpenTask,
                      ),
                    ),
                    SizedBox(width: 24),
                    Expanded(
                      flex: 40,
                      child: actions.maybeWhen(
                        data: (items) => ActionsZone(
                          actions: items,
                          onOpenTask: (t) => onOpenTask(context, ref, t),
                        ),
                        orElse: () => ActionsZone(actions: const []),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              DdJournal(),
            ]),
          ),
        ),
      ],
    );
  }
}

class _TasksColumn extends ConsumerWidget {
  _TasksColumn({
    required this.tasks,
    required this.onOpenTaskMenu,
    required this.onOpenTask,
  });

  final List<Task> tasks;
  final void Function(BuildContext, WidgetRef, Task) onOpenTaskMenu;
  final void Function(BuildContext, WidgetRef, Task) onOpenTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'TASKS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: context.colors.muted,
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: 12),
                child: Divider(color: context.colors.border, height: 1),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        if (tasks.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Nothing planned for this day.',
              style: TextStyle(
                color: context.colors.dim,
                fontStyle: FontStyle.italic,
                fontSize: 13,
              ),
            ),
          )
        else
          ...tasks.map(
            (t) => Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: DdTaskRow(
                task: t,
                onTap: () => onOpenTask(context, ref, t),
                onMenu: () => onOpenTaskMenu(context, ref, t),
              ),
            ),
          ),
      ],
    );
  }
}
