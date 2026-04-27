import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_projects/data/providers.dart';
import 'package:nx_projects/domain/project/project.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/features/filters/filter_state_providers.dart';

class ProjectListRow {
  const ProjectListRow({
    required this.project,
    required this.taskCount,
    required this.hours,
  });

  final Project project;
  final int taskCount;
  final double hours;
}

bool _passesKindFilter(Task t, Set<String> kinds) {
  if (kinds.isEmpty) return true;
  return kinds.contains(t.kind.name);
}

bool _passesStatusFilter(Task t, Set<String> statuses) {
  if (statuses.isEmpty) return true;
  return statuses.contains(t.status.name);
}

bool _passesProjectFilter(Task t, Set<int> selectedProjects) {
  if (selectedProjects.isEmpty) return true;
  return (t.projectId != null && selectedProjects.contains(t.projectId)) ||
      (t.subProjectId != null && selectedProjects.contains(t.subProjectId));
}

bool _matchQuery(Task t, String q) {
  if (q.isEmpty) return true;
  return t.title.toLowerCase().contains(q) || t.crumb.toLowerCase().contains(q);
}

final projectListRowsProvider = Provider<List<ProjectListRow>>((ref) {
  final projects = ref.watch(projectsListProvider);
  final tasks = ref.watch(tasksListProvider);
  final q = ref.watch(searchQueryProvider).trim().toLowerCase();
  final kind = ref.watch(filterKindSetProvider);
  final status = ref.watch(filterStatusSetProvider);
  final selectedProjects = ref.watch(filterProjectIdsProvider);
  final roots = projects.where((p) => p.parentId == null).toList();
  return roots.map((p) {
    final pTasks = tasks.where((t) {
      if (t.projectId != p.id) return false;
      return _matchQuery(t, q) &&
          _passesKindFilter(t, kind) &&
          _passesStatusFilter(t, status) &&
          _passesProjectFilter(t, selectedProjects);
    });
    return ProjectListRow(
      project: p,
      taskCount: pTasks.length,
      hours: pTasks.fold<double>(0, (a, t) => a + t.estimate),
    );
  }).toList();
});

final projectDetailTasksProvider = Provider.family<List<Task>, int>((
  ref,
  projectId,
) {
  final tasks = ref.watch(tasksListProvider);
  final q = ref.watch(searchQueryProvider).trim().toLowerCase();
  final kind = ref.watch(filterKindSetProvider);
  final status = ref.watch(filterStatusSetProvider);
  final selectedProjects = ref.watch(filterProjectIdsProvider);
  return tasks
      .where(
        (t) =>
            t.projectId == projectId &&
            _matchQuery(t, q) &&
            _passesKindFilter(t, kind) &&
            _passesStatusFilter(t, status) &&
            _passesProjectFilter(t, selectedProjects),
      )
      .toList();
});

final subProjectListRowsProvider = Provider.family<List<ProjectListRow>, int>((
  ref,
  parentId,
) {
  final projects = ref.watch(projectsListProvider);
  final tasks = ref.watch(tasksListProvider);
  final q = ref.watch(searchQueryProvider).trim().toLowerCase();
  final kind = ref.watch(filterKindSetProvider);
  final status = ref.watch(filterStatusSetProvider);
  final selectedProjects = ref.watch(filterProjectIdsProvider);
  final subs = projects.where((p) => p.parentId == parentId).toList();
  return subs.map((sp) {
    final sTasks = tasks.where((t) {
      if (t.projectId != parentId || t.subProjectId != sp.id) return false;
      return _matchQuery(t, q) &&
          _passesKindFilter(t, kind) &&
          _passesStatusFilter(t, status) &&
          _passesProjectFilter(t, selectedProjects);
    });
    return ProjectListRow(
      project: sp,
      taskCount: sTasks.length,
      hours: sTasks.fold<double>(0, (a, t) => a + t.estimate),
    );
  }).toList();
});

final subProjectTasksProvider =
    Provider.family<List<Task>, ({int projectId, int subId})>((ref, key) {
      final tasks = ref.watch(tasksListProvider);
      final q = ref.watch(searchQueryProvider).trim().toLowerCase();
      final kind = ref.watch(filterKindSetProvider);
      final status = ref.watch(filterStatusSetProvider);
      final selectedProjects = ref.watch(filterProjectIdsProvider);
      return tasks
          .where(
            (t) =>
                t.projectId == key.projectId &&
                t.subProjectId == key.subId &&
                _matchQuery(t, q) &&
                _passesKindFilter(t, kind) &&
                _passesStatusFilter(t, status) &&
                _passesProjectFilter(t, selectedProjects),
          )
          .toList();
    });
