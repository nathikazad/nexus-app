import 'package:flutter/material.dart' hide Action;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icon_pack/solar_icon_pack.dart';

import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/core/widgets/task_status_segmented.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/features/action_detail/action_detail_page.dart';
import 'package:nx_time/features/action_detail/action_detail_view_model.dart';
import 'package:nx_time/features/tasks/task_create_page.dart';
import 'package:nx_time/features/tasks/task_detail_view_model.dart';
import 'package:nx_time/features/tasks/task_edit_page.dart';
import 'package:nx_time/features/tasks/task_status.dart';
import 'package:nx_time/features/tasks/task_view_models.dart';

class TaskDetailPage extends ConsumerStatefulWidget {
  const TaskDetailPage({super.key, required this.taskId});

  final int taskId;

  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage> {
  Future<void> _onStatusChanged(TaskStatus s) async {
    final repo = ref.read(taskRepositoryProvider);
    await repo.updateStatus(id: widget.taskId, status: s);
    ref.invalidate(taskDetailProvider(widget.taskId));
    ref.invalidate(taskDetailScreenVmProvider(widget.taskId));
    ref.invalidate(subtasksOfTaskProvider(widget.taskId));
    ref.invalidate(tasksForTodayProvider);
    ref.invalidate(allTasksProvider);
  }

  Future<void> _moveToTomorrow() async {
    final task = await ref.read(taskDetailProvider(widget.taskId).future);
    if (task == null || !mounted) return;
    final next = calendarDay(DateTime.now()).add(const Duration(days: 1));
    final repo = ref.read(taskRepositoryProvider);
    await repo.update(task.copyWith(date: next), includeAttributes: true);
    _invalidateAll();
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _unpinFromToday() async {
    final task = await ref.read(taskDetailProvider(widget.taskId).future);
    if (task == null || !mounted) return;
    final repo = ref.read(taskRepositoryProvider);
    await repo.update(
      task.copyWith(date: null),
      includeAttributes: true,
    );
    _invalidateAll();
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _delete() async {
    final repo = ref.read(taskRepositoryProvider);
    await repo.delete(widget.taskId);
    ref.invalidate(tasksForTodayProvider);
    ref.invalidate(allTasksProvider);
    if (mounted) Navigator.of(context).maybePop();
  }

  void _invalidateAll() {
    ref.invalidate(taskDetailProvider(widget.taskId));
    ref.invalidate(taskDetailScreenVmProvider(widget.taskId));
    ref.invalidate(subtasksOfTaskProvider(widget.taskId));
    ref.invalidate(tasksForTodayProvider);
    ref.invalidate(allTasksProvider);
  }

  void _openEdit() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TaskEditPage(taskId: widget.taskId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(taskDetailProvider(widget.taskId));
    final vmAsync = ref.watch(taskDetailScreenVmProvider(widget.taskId));
    final subtasksAsync = ref.watch(subtasksOfTaskProvider(widget.taskId));

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: taskAsync.when(
          data: (task) {
            if (task == null) {
              return const Center(child: Text('Task not found'));
            }
            return vmAsync.when(
              data: (vm) {
                if (vm == null) {
                  return const Center(child: Text('Task not found'));
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(SolarLinearIcons.arrowLeft, size: 22),
                            color: AppColors.slate600,
                          ),
                          const Expanded(
                            child: Text(
                              'TASK',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                                color: AppColors.slate900,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _openEdit,
                            child: const Text(
                              'Edit',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        children: [
                          Text(
                            vm.title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                              color: AppColors.slate900,
                            ),
                          ),
                          if (vm.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              vm.subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.slate500,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          _dateTimeCard(vm),
                          const SizedBox(height: 16),
                          TaskStatusSegmented(
                            value: task.status,
                            onChanged: _onStatusChanged,
                          ),
                          const SizedBox(height: 24),
                          subtasksAsync.when(
                            data: (subs) {
                              if (subs.isEmpty) {
                                return TextButton(
                                  onPressed: () async {
                                    await Navigator.of(context).push<int?>(
                                      MaterialPageRoute(
                                        builder: (_) => TaskCreatePage(
                                          parentTaskId: widget.taskId,
                                        ),
                                      ),
                                    );
                                    ref.invalidate(
                                      subtasksOfTaskProvider(widget.taskId),
                                    );
                                    ref.invalidate(
                                      taskDetailScreenVmProvider(widget.taskId),
                                    );
                                  },
                                  child: const Text('+ add subtask'),
                                );
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'SUBTASKS',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 1,
                                          color: AppColors.slate500,
                                        ),
                                      ),
                                      Text(
                                        '${vm.subtaskDoneCount} of ${vm.subtaskTotal}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.slate900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ...subs.map(
                                    (s) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(s.name),
                                      subtitle: Text(s.status.label),
                                      onTap: () {
                                        Navigator.of(context).push<void>(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                TaskDetailPage(taskId: s.id),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      await Navigator.of(context).push<int?>(
                                        MaterialPageRoute(
                                          builder: (_) => TaskCreatePage(
                                            parentTaskId: widget.taskId,
                                          ),
                                        ),
                                      );
                                      ref.invalidate(
                                        subtasksOfTaskProvider(widget.taskId),
                                      );
                                      ref.invalidate(
                                        taskDetailScreenVmProvider(
                                          widget.taskId,
                                        ),
                                      );
                                    },
                                    child: const Text('+ add subtask'),
                                  ),
                                ],
                              );
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                          if (vm.notesPreview != null) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'NOTES',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1,
                                color: AppColors.slate500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              vm.notesPreview!,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: AppColors.slate600,
                              ),
                            ),
                          ],
                          if (vm.linkedActivitySummaries.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            const Text(
                              'Actions',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1,
                                color: AppColors.slate500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...vm.linkedActivitySummaries.map((line) {
                              return _linkedActivityTile(
                                context,
                                line,
                              );
                            }),
                          ],
                          const SizedBox(height: 24),
                          const Divider(color: AppColors.slate100),
                          _DetailAction(
                            icon: SolarLinearIcons.calendar,
                            title: 'Move to different day',
                            subtitle: 'Repin this task (tomorrow)',
                            onTap: _moveToTomorrow,
                          ),
                          _DetailAction(
                            icon: SolarLinearIcons.archive,
                            title: 'Unpin from today',
                            subtitle: 'Clear calendar date',
                            onTap: _unpinFromToday,
                          ),
                          _DetailAction(
                            icon: SolarLinearIcons.trashBinMinimalistic,
                            title: 'Delete task',
                            subtitle: 'This cannot be undone',
                            destructive: true,
                            onTap: _delete,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
        ),
      ),
    );
  }

  Widget _dateTimeCard(TaskDetailVm vm) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate100),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const Text(
                  'DATE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    color: AppColors.slate400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  vm.dateLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate900,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 28, color: AppColors.slate200),
          Expanded(
            child: Text(
              vm.timeRangeLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.slate900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _linkedActivityTile(
    BuildContext context,
    LinkedActivityLineVm line,
  ) {
    final act = line.action;
    final colors = modelTypeColorsOrFallback(
      ref.watch(modelTypeColorsProvider),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: act == null
            ? null
            : () {
                final args = activityDetailArgsForAction(
                  act,
                  '',
                  colors,
                );
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => ActivityDetailPage(args: args),
                  ),
                );
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate900,
                      ),
                    ),
                    Text(
                      line.subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.slate400,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                line.durationLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.slate500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailAction extends StatelessWidget {
  const _DetailAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final fg = destructive ? const Color(0xFFEF4444) : AppColors.slate900;
    final iconBg = destructive ? const Color(0xFFFEF2F2) : AppColors.slate100;
    final iconFg = destructive ? const Color(0xFFEF4444) : AppColors.slate600;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: iconFg),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: fg,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
