import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/data/providers.dart';
import 'package:nx_projects/domain/project/project.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_kind.dart';
import 'package:nx_projects/domain/task/task_status.dart';
import 'package:nx_projects/features/filters/filter_state_providers.dart';

class ProjectListRow {
  const ProjectListRow({required this.project, required this.taskCount, required this.hours});

  final Project project;
  final int taskCount;
  final double hours;
}

bool _passesFilters(Task t, String kind, String status) {
  if (kind == 'feat' && t.kind != TaskKind.feat) return false;
  if (kind == 'bug' && t.kind != TaskKind.bug) return false;
  if (status == 'open' && t.status == TaskStatus.done) return false;
  if (status == 'done' && t.status != TaskStatus.done) return false;
  return true;
}

bool _matchQuery(Task t, String q) {
  if (q.isEmpty) return true;
  return t.title.toLowerCase().contains(q) || t.crumb.toLowerCase().contains(q);
}

final projectListRowsProvider = Provider<List<ProjectListRow>>((ref) {
  final projects = ref.watch(projectsListProvider);
  final tasks = ref.watch(tasksListProvider);
  final q = ref.watch(searchQueryProvider).trim().toLowerCase();
  final kind = ref.watch(filterKindProvider);
  final status = ref.watch(filterStatusProvider);
  final roots = projects.where((p) => p.parentId == null).toList();
  return roots.map((p) {
    final pTasks = tasks.where((t) {
      if (t.projectId != p.id) return false;
      return _matchQuery(t, q) && _passesFilters(t, kind, status);
    });
    return ProjectListRow(
      project: p,
      taskCount: pTasks.length,
      hours: pTasks.fold<double>(0, (a, t) => a + t.estimate),
    );
  }).toList();
});

final projectDetailTasksProvider = Provider.family<List<Task>, String>((ref, projectId) {
  final tasks = ref.watch(tasksListProvider);
  final q = ref.watch(searchQueryProvider).trim().toLowerCase();
  final kind = ref.watch(filterKindProvider);
  final status = ref.watch(filterStatusProvider);
  return tasks
      .where(
        (t) =>
            t.projectId == projectId &&
            _matchQuery(t, q) &&
            _passesFilters(t, kind, status),
      )
      .toList();
});

final subProjectListRowsProvider = Provider.family<List<ProjectListRow>, String>((ref, parentId) {
  final projects = ref.watch(projectsListProvider);
  final tasks = ref.watch(tasksListProvider);
  final q = ref.watch(searchQueryProvider).trim().toLowerCase();
  final kind = ref.watch(filterKindProvider);
  final status = ref.watch(filterStatusProvider);
  final subs = projects.where((p) => p.parentId == parentId).toList();
  return subs.map((sp) {
    final sTasks = tasks.where((t) {
      if (t.projectId != parentId || t.subProjectId != sp.id) return false;
      return _matchQuery(t, q) && _passesFilters(t, kind, status);
    });
    return ProjectListRow(
      project: sp,
      taskCount: sTasks.length,
      hours: sTasks.fold<double>(0, (a, t) => a + t.estimate),
    );
  }).toList();
});

final subProjectTasksProvider =
    Provider.family<List<Task>, ({String projectId, String subId})>((ref, key) {
  final tasks = ref.watch(tasksListProvider);
  final q = ref.watch(searchQueryProvider).trim().toLowerCase();
  final kind = ref.watch(filterKindProvider);
  final status = ref.watch(filterStatusProvider);
  return tasks
      .where(
        (t) =>
            t.projectId == key.projectId &&
            t.subProjectId == key.subId &&
            _matchQuery(t, q) &&
            _passesFilters(t, kind, status),
      )
      .toList();
});
