import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/core/widgets/nx_tab_header.dart';
import 'package:nx_time/core/widgets/task_row_tile.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/domain/tasks/task_status.dart';
import 'package:nx_time/features/tasks/task_detail_page.dart';
import 'package:nx_time/features/tasks/task_picker_page.dart';
import 'package:nx_time/features/tasks/task_view_models.dart';

class TasksPage extends ConsumerWidget {
  const TasksPage({super.key});

  static String _tasksHeaderTitle(DateTime dayLocal) {
    return 'Tasks — ${DateFormat('EEE, MMM d').format(dayLocal)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksForTodayProvider);
    final crumbsAsync = ref.watch(projectBreadcrumbLabelsProvider);
    final day = calendarDay(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NxTabHeader(
          clockLabel: DateFormat.jm().format(DateTime.now()),
          title: _tasksHeaderTitle(day),
          bottomBorder: true,
          borderColor: AppColors.slate50,
        ),
        tasksAsync.when(
          data: (tasks) {
            final crumbs = crumbsAsync.when(
              data: (d) => d,
              loading: () => const <int, String>{},
              error: (_, __) => const <int, String>{},
            );
            final summary = taskListSummary(tasks);
            final rows = taskRowVmsFromTasks(tasks, crumbs);
            return Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.slate100)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _Chip(
                                  label: '${summary.total} Total',
                                  bg: AppColors.slate100,
                                  border: AppColors.slate200,
                                  fg: AppColors.slate600,
                                ),
                                const SizedBox(width: 8),
                                _Chip(
                                  label: '${summary.doneCount} Done',
                                  bg: const Color(0xFFF0FDF4),
                                  border: const Color(0xFFDCFCE7),
                                  fg: const Color(0xFF15803D),
                                ),
                                const SizedBox(width: 8),
                                _Chip(
                                  label: '${summary.todoCount} Todo',
                                  bg: AppColors.slate50,
                                  border: AppColors.slate100,
                                  fg: AppColors.slate500,
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            final picked = await Navigator.of(context)
                                .push<Set<int>?>(
                              MaterialPageRoute(
                                builder: (_) => const TaskPickerPage(),
                              ),
                            );
                            if (picked == null || picked.isEmpty) return;
                            final repo = ref.read(taskRepositoryProvider);
                            await pinTaskIdsToCalendarDay(
                              repo,
                              picked,
                              DateTime.now(),
                            );
                            ref.invalidate(tasksForTodayProvider);
                            ref.invalidate(allTasksProvider);
                          },
                          tooltip: 'Pick tasks',
                          style: IconButton.styleFrom(
                            foregroundColor: AppColors.accent,
                            hoverColor: AppColors.accentLight,
                          ),
                          icon: const Icon(SolarLinearIcons.addCircle, size: 26),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: rows.isEmpty
                        ? const Center(
                            child: Text(
                              'No tasks pinned to today',
                              style: TextStyle(color: AppColors.slate500),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                            itemCount: rows.length + 1,
                            itemBuilder: (context, i) {
                              if (i == 0) {
                                return const Padding(
                                  padding: EdgeInsets.only(bottom: 16),
                                  child: Text(
                                    'SWIPE RIGHT = DONE • LONG PRESS TO REORDER',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 1.2,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.slate400,
                                    ),
                                  ),
                                );
                              }
                              final row = rows[i - 1];
                              final task = tasks.firstWhere((t) => t.id == row.taskId);
                              return Dismissible(
                                key: ValueKey('task_row_${row.taskId}'),
                                direction: DismissDirection.endToStart,
                                confirmDismiss: (_) async {
                                  if (task.status == TaskStatus.done) {
                                    return false;
                                  }
                                  final repo = ref.read(taskRepositoryProvider);
                                  await repo.updateStatus(
                                    id: task.id,
                                    status: TaskStatus.done,
                                  );
                                  ref.invalidate(tasksForTodayProvider);
                                  return false;
                                },
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  color: const Color(0xFF15803D),
                                  child: const Text(
                                    'Done',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                child: TaskRowTile(
                                  title: row.title,
                                  subtitle: row.subtitle,
                                  durationLabel: row.durationLabel,
                                  done: row.isDone,
                                  onTap: () {
                                    Navigator.of(context).push<void>(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            TaskDetailPage(taskId: row.taskId),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Expanded(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load tasks: $e'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.bg,
    required this.border,
    required this.fg,
  });

  final String label;
  final Color bg;
  final Color border;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }
}
