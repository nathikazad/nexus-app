import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/data/domains/domain_appearance.dart';
import 'package:nx_time/data/domains/domain_workspace.dart';
import 'package:nx_time/features/tasks/task_detail_page.dart';
import 'package:nx_time/features/tasks/task_view_models.dart';

class RecentlyCompletedTasks extends ConsumerStatefulWidget {
  const RecentlyCompletedTasks({super.key});
  @override
  ConsumerState<RecentlyCompletedTasks> createState() =>
      _RecentlyCompletedTasksState();
}

class _RecentlyCompletedTasksState
    extends ConsumerState<RecentlyCompletedTasks> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    final recent = ref.watch(recentlyCompletedTasksProvider);
    final today = ref.watch(taskCalendarDayProvider);
    final workspace = ref.watch(timeDomainsProvider).asData?.value;
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(color: AppColors.slate100),
          const SizedBox(height: 12),
          const Text(
            'Recently completed',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.slate900,
            ),
          ),
          const SizedBox(height: 12),
          recent.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => TextButton(
              onPressed: () => ref.invalidate(allTasksProvider),
              child: const Text('Retry completed tasks'),
            ),
            data: (tasks) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (tasks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No tasks completed today or yesterday.',
                      style: TextStyle(fontSize: 13, color: AppColors.slate500),
                    ),
                  ),
                for (final task in expanded ? tasks : tasks.take(5))
                  Builder(
                    builder: (context) {
                      final appearance = domainAppearance(
                        ref,
                        workspace?.origins[task.id],
                      );
                      final completed = task.completedAt!;
                      final day = calendarDay(completed) == today
                          ? 'Today'
                          : 'Yesterday';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: appearance.secondary.withValues(alpha: .045),
                          border: Border(
                            left: BorderSide(
                              color: appearance.accent.withValues(alpha: .3),
                              width: 2,
                            ),
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            leading: Icon(
                              Icons.check_circle_outline_rounded,
                              color: appearance.accent,
                              size: 22,
                            ),
                            title: Text(
                              task.name,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.slate600,
                              ),
                            ),
                            subtitle: Text(
                              '$day · ${DateFormat.jm().format(completed)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.slate500,
                              ),
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => TaskDetailPage(taskId: task.id),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                if (tasks.length > 5)
                  TextButton(
                    onPressed: () => setState(() => expanded = !expanded),
                    child: Text(
                      expanded ? 'Show less' : 'Show ${tasks.length - 5} more',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
