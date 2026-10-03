import 'package:nx_time/data/domains/domain_appearance.dart';
import 'package:nx_time/features/tasks/recently_completed_tasks.dart';
import 'package:nx_time/features/tasks/task_participants.dart';
import 'package:nx_time/data/domains/domain_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksForTodayProvider);
    final crumbsAsync = ref.watch(projectBreadcrumbLabelsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const NxTabHeader(
          title: 'Tasks',
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
            final recent = ref
                .watch(recentlyCompletedTasksProvider)
                .asData
                ?.value;
            final today = ref.watch(taskCalendarDayProvider);
            final doneToday = recent
                ?.where((task) => calendarDay(task.completedAt!) == today)
                .length;
            final rows = taskRowVmsFromTasks(tasks, crumbs);
            final workspace = ref.watch(timeDomainsProvider).asData?.value;
            if (workspace != null) {
              final byId = {for (final task in tasks) task.id: task};
              rows.sort((a, b) {
                final order = taskRank(
                  byId[a.taskId]!,
                  workspace,
                ).compareTo(taskRank(byId[b.taskId]!, workspace));
                return order != 0 ? order : a.taskId.compareTo(b.taskId);
              });
            }
            bool inMainList(TaskRowVm row) =>
                workspace == null ||
                taskInMainList(
                  tasks.firstWhere((task) => task.id == row.taskId),
                  personal:
                      workspace.origins[row.taskId] == workspace.personalId,
                  userId: '${workspace.user.userId}',
                );
            final primary = rows.where(inMainList).toList();
            final others = rows.where((row) => !inMainList(row)).toList();
            Widget section(
              String storageKey,
              List<TaskRowVm> rows,
            ) => ReorderableListView.builder(
              key: PageStorageKey(storageKey),
              buildDefaultDragHandles: false,
              onReorder: (oldIndex, newIndex) async {
                if (newIndex > oldIndex) newIndex--;
                if (oldIndex == newIndex || workspace == null) return;
                final ordered = [
                  for (final row in rows)
                    tasks.firstWhere((t) => t.id == row.taskId),
                ];
                final moved = ordered.removeAt(oldIndex);
                ordered.insert(newIndex, moved);
                try {
                  final rank = rankBetween(
                    newIndex == 0
                        ? null
                        : taskRank(ordered[newIndex - 1], workspace),
                    newIndex == ordered.length - 1
                        ? null
                        : taskRank(ordered[newIndex + 1], workspace),
                  );
                  await saveTaskRank(ref, moved, rank);
                } catch (e) {
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not reorder: $e')),
                    );
                }
              },
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: rows.length,

              header: rows.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No open tasks',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.slate500,
                        ),
                      ),
                    )
                  : const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final row = rows[i];
                final appearance = domainAppearance(
                  ref,
                  workspace?.origins[row.taskId],
                );
                final task = tasks.firstWhere((t) => t.id == row.taskId);
                return Dismissible(
                  key: ValueKey('task_row_${row.taskId}'),
                  direction:
                      ref
                              .watch(timeDomainsProvider)
                              .value
                              ?.canWriteModel(task.id) ==
                          false
                      ? DismissDirection.none
                      : DismissDirection.endToStart,
                  confirmDismiss: (_) async {
                    if (task.status == TaskStatus.done) {
                      return false;
                    }
                    final repo = ref.read(taskRepositoryProvider);
                    await repo.updateStatus(
                      id: task.id,
                      status: TaskStatus.done,
                    );
                    invalidateTasksAfterMutation(ref);
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
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: appearance.secondary.withValues(alpha: 0.045),
                      border: Border(
                        left: BorderSide(
                          color: appearance.accent.withValues(alpha: 0.25),
                          width: 2,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TaskRowTile(
                                title: row.title,
                                subtitle: [
                                  appearance.label,
                                  if (row.subtitle.isNotEmpty) row.subtitle,
                                ].join(' · '),
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
                            ),
                            if (workspace?.canWriteModel(task.id) == true)
                              ReorderableDragStartListener(
                                index: i,
                                child: const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Icon(
                                    Icons.drag_handle_rounded,
                                    color: AppColors.slate400,
                                    size: 20,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (storageKey == 'other_task_order')
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 44,
                              bottom: 10,
                            ),
                            child: TaskAssignment(task: task, compact: true),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
            return Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.slate100),
                      ),
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
                                  label: '${tasks.length} Open',
                                  bg: AppColors.slate100,
                                  border: AppColors.slate200,
                                  fg: AppColors.slate600,
                                ),
                                const SizedBox(width: 8),
                                _Chip(
                                  label: '${doneToday ?? '—'} Done today',
                                  bg: const Color(0xFFF0FDF4),
                                  border: const Color(0xFFDCFCE7),
                                  fg: const Color(0xFF15803D),
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
                          icon: const Icon(
                            SolarLinearIcons.addCircle,
                            size: 26,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                      children: [
                        section('primary_task_order', primary),
                        if (others.isNotEmpty)
                          ExpansionTile(
                            key: const PageStorageKey('other_tasks'),
                            initiallyExpanded: false,
                            tilePadding: EdgeInsets.zero,
                            shape: const Border(),
                            collapsedShape: const Border(),
                            title: Text(
                              'Other Tasks (${others.length})',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.slate500,
                              ),
                            ),
                            children: [section('other_task_order', others)],
                          ),
                        const RecentlyCompletedTasks(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () =>
              const Expanded(child: Center(child: CircularProgressIndicator())),
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
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: fg),
      ),
    );
  }
}
