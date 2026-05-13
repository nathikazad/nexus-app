import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nx_time/core/formatting/time_format.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/domain/action/action.dart';
import 'package:nx_time/domain/tasks/task.dart';
import 'package:nx_time/domain/tasks/task_status.dart';
import 'package:nx_time/features/tasks/task_view_models.dart';

/// Presentation bundle for [TaskDetailPage] (strings + counts).
class TaskDetailVm {
  const TaskDetailVm({
    required this.title,
    required this.subtitle,
    required this.durationLabel,
    required this.dateLabel,
    required this.timeRangeLabel,
    required this.notesPreview,
    required this.subtaskDoneCount,
    required this.subtaskTotal,
    required this.linkedActivitySummaries,
  });

  final String title;
  final String subtitle;
  final String durationLabel;
  final String dateLabel;
  final String timeRangeLabel;
  final String? notesPreview;
  final int subtaskDoneCount;
  final int subtaskTotal;
  final List<LinkedActivityLineVm> linkedActivitySummaries;
}

class LinkedActivityLineVm {
  const LinkedActivityLineVm({
    required this.title,
    required this.subtitle,
    required this.durationLabel,
    required this.link,
    this.action,
  });

  final String title;
  final String subtitle;
  final String durationLabel;
  final TaskActivityLink link;
  final Action? action;
}

TaskDetailVm taskDetailVmFromTask({
  required Task task,
  required String projectSubtitle,
  required List<Task> subtasks,
  required List<Action?> linkedActions,
}) {
  final timeFmt = DateFormat.jm();
  final date = task.date;
  final dateLabel = date != null ? DateFormat('EEE, MMM d').format(date) : '—';
  final timeRangeLabel = formatTimeRange(timeFmt, task.startTime, task.endTime);

  var done = 0;
  for (final s in subtasks) {
    if (s.status == TaskStatus.done) done++;
  }

  final summaries = <LinkedActivityLineVm>[];
  for (var i = 0; i < task.linkedActivities.length; i++) {
    final link = task.linkedActivities[i];
    final act = i < linkedActions.length ? linkedActions[i] : null;
    final title = act?.name.isNotEmpty == true
        ? act!.name
        : 'Activity ${link.activityId}';
    final range = act != null
        ? formatTimeRange(timeFmt, act.startTime, act.endTime)
        : '—';
    final dur = act != null
        ? formatDurationHm(act.startTime, act.endTime)
        : '—';
    summaries.add(
      LinkedActivityLineVm(
        title: title,
        subtitle: range,
        durationLabel: dur,
        link: link,
        action: act,
      ),
    );
  }

  return TaskDetailVm(
    title: task.name.isEmpty ? 'Task' : task.name,
    subtitle: projectSubtitle,
    durationLabel: formatDurationHm(task.startTime, task.endTime),
    dateLabel: dateLabel,
    timeRangeLabel: timeRangeLabel,
    notesPreview: task.description?.trim().isEmpty ?? true
        ? null
        : task.description,
    subtaskDoneCount: done,
    subtaskTotal: subtasks.length,
    linkedActivitySummaries: summaries,
  );
}

final linkedActionsForTaskProvider = FutureProvider.family<List<Action?>, int>((
  ref,
  taskId,
) async {
  await ref.watch(authenticatedUserProvider.future);
  final task = await ref.watch(taskDetailProvider(taskId).future);
  if (task == null) return [];
  final repo = ref.read(actionRepositoryProvider);
  final out = <Action?>[];
  for (final link in task.linkedActivities) {
    out.add(
      await repo.getById(
        id: link.activityId,
        modelTypeName: link.activityModelTypeName,
      ),
    );
  }
  return out;
});

final taskDetailScreenVmProvider = FutureProvider.family<TaskDetailVm?, int>((
  ref,
  taskId,
) async {
  final task = await ref.watch(taskDetailProvider(taskId).future);
  if (task == null) return null;
  final crumbs = await ref.watch(projectBreadcrumbLabelsProvider.future);
  final projectSubtitle = task.projectId != null
      ? (crumbs[task.projectId!] ?? '')
      : '';
  final subtasks = await ref.watch(subtasksOfTaskProvider(taskId).future);
  final linked = await ref.watch(linkedActionsForTaskProvider(taskId).future);
  return taskDetailVmFromTask(
    task: task,
    projectSubtitle: projectSubtitle,
    subtasks: subtasks,
    linkedActions: linked,
  );
});
