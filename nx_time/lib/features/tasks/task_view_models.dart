import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_time/core/formatting/time_format.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/domain/projects/project.dart';
import 'package:nx_time/domain/tasks/task.dart';
import 'package:nx_time/domain/tasks/task_repository.dart';
import 'package:nx_time/domain/tasks/task_status.dart';

/// Local calendar day at midnight.
DateTime calendarDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Chip summary for the tasks header.
({int total, int doneCount, int todoCount}) taskListSummary(List<Task> tasks) {
  final total = tasks.length;
  var done = 0;
  for (final t in tasks) {
    if (t.status == TaskStatus.done) done++;
  }
  return (total: total, doneCount: done, todoCount: total - done);
}

/// One row on the main Tasks list.
class TaskRowVm {
  const TaskRowVm({
    required this.taskId,
    required this.title,
    required this.subtitle,
    required this.durationLabel,
    required this.isDone,
  });

  final int taskId;
  final String title;
  final String subtitle;
  final String durationLabel;
  final bool isDone;
}

List<TaskRowVm> taskRowVmsFromTasks(
  List<Task> tasks,
  Map<int, String> projectBreadcrumbByProjectId,
) {
  final sorted = List<Task>.from(tasks)
    ..sort((a, b) {
      final sa = a.startTime;
      final sb = b.startTime;
      if (sa != null && sb != null) {
        final c = sa.compareTo(sb);
        if (c != 0) return c;
      }
      return a.name.compareTo(b.name);
    });
  return sorted
      .map(
        (t) => TaskRowVm(
          taskId: t.id,
          title: t.name.isEmpty ? 'Task' : t.name,
          subtitle: t.projectId != null
              ? (projectBreadcrumbByProjectId[t.projectId] ??
                    'Project ${t.projectId}')
              : '',
          durationLabel: formatDurationHm(t.startTime, t.endTime),
          isDone: t.status == TaskStatus.done,
        ),
      )
      .toList();
}

/// `projectId` → `"Root › Child › Leaf"` for task subtitles.
Map<int, String> projectBreadcrumbLabels(List<Project> all) {
  final byId = {for (final p in all) p.id: p};
  final parentOf = <int, int>{};
  for (final p in all) {
    for (final c in p.childProjectIds) {
      parentOf[c] = p.id;
    }
  }
  String labelFor(int projectId) {
    final parts = <String>[];
    var cur = projectId;
    final seen = <int>{};
    while (true) {
      if (!seen.add(cur)) break;
      final p = byId[cur];
      if (p == null) break;
      parts.add(p.name);
      final parent = parentOf[cur];
      if (parent == null) break;
      cur = parent;
    }
    return parts.reversed.join(' › ');
  }

  return {for (final p in all) p.id: labelFor(p.id)};
}

final allProjectsProvider = FutureProvider<List<Project>>((ref) async {
  await ref.watch(authenticatedUserProvider.future);
  return ref.read(projectRepositoryProvider).listAll();
});

final projectBreadcrumbLabelsProvider = FutureProvider<Map<int, String>>((
  ref,
) async {
  final projects = await ref.watch(allProjectsProvider.future);
  return projectBreadcrumbLabels(projects);
});

final tasksForTodayProvider = FutureProvider<List<Task>>((ref) async {
  await ref.watch(authenticatedUserProvider.future);
  final day = calendarDay(DateTime.now());
  return ref.read(taskRepositoryProvider).listAll(onDate: day);
});

final allTasksProvider = FutureProvider<List<Task>>((ref) async {
  await ref.watch(authenticatedUserProvider.future);
  return ref.read(taskRepositoryProvider).listAll();
});

final taskDetailProvider = FutureProvider.family<Task?, int>((ref, id) async {
  await ref.watch(authenticatedUserProvider.future);
  return ref.read(taskRepositoryProvider).getById(id);
});

final subtasksOfTaskProvider = FutureProvider.family<List<Task>, int>((
  ref,
  parentId,
) async {
  await ref.watch(authenticatedUserProvider.future);
  final parent = await ref.watch(taskDetailProvider(parentId).future);
  if (parent == null) return [];
  final repo = ref.read(taskRepositoryProvider);
  final out = <Task>[];
  for (final cid in parent.childTaskIds) {
    final c = await repo.getById(cid);
    if (c != null) out.add(c);
  }
  out.sort((a, b) => a.name.compareTo(b.name));
  return out;
});

/// Pins each task id to [dayLocal]'s calendar day (`date` attribute).
Future<void> pinTaskIdsToCalendarDay(
  TaskRepository repo,
  Iterable<int> taskIds,
  DateTime dayLocal,
) async {
  final day = calendarDay(dayLocal);
  for (final id in taskIds) {
    final t = await repo.getById(id);
    if (t == null) continue;
    await repo.update(t.copyWith(date: day), includeAttributes: true);
  }
}

/// Tasks whose `link_to_action` relation includes [activityId].
Future<List<Task>> tasksLinkedToActivity(
  TaskRepository repo,
  int activityId,
) async {
  final all = await repo.listAll();
  return all
      .where((t) => t.linkedActivities.any((l) => l.activityId == activityId))
      .toList();
}

/// Derived view of [allTasksProvider] filtered to tasks linked to a given activity id.
///
/// Because it `watch`es [allTasksProvider], any invalidation of that provider
/// (status change, edit, link, etc.) propagates here automatically.
final tasksLinkedToActivityProvider = FutureProvider.family<List<Task>, int>((
  ref,
  activityId,
) async {
  final all = await ref.watch(allTasksProvider.future);
  return all
      .where((t) => t.linkedActivities.any((l) => l.activityId == activityId))
      .toList();
});

/// Refetches task lists and any mounted task detail/link views after external
/// changes, such as returning to the app after it was backgrounded.
void invalidateTasksAfterMutation(WidgetRef ref) {
  ref.invalidate(tasksForTodayProvider);
  ref.invalidate(allTasksProvider);
  ref.invalidate(taskDetailProvider);
  ref.invalidate(subtasksOfTaskProvider);
  ref.invalidate(tasksLinkedToActivityProvider);
}
