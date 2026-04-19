import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_time/data/providers.dart';
import 'package:nx_time/domain/projects/project.dart';
import 'package:nx_time/domain/tasks/task.dart';
import 'package:nx_time/features/tasks/task_view_models.dart';

enum ProjectsBrowseMode { browse, pickProject, pickTask }

class ProjectBrowseRowVm {
  const ProjectBrowseRowVm({
    required this.project,
    required this.subProjectCount,
    required this.taskCountInSubtree,
    required this.subtitle,
  });

  final Project project;
  final int subProjectCount;
  final int taskCountInSubtree;
  final String subtitle;
}

Set<int> descendantProjectIds(int rootId, List<Project> all) {
  final byId = {for (final p in all) p.id: p};
  final out = <int>{rootId};
  void walk(int id) {
    final p = byId[id];
    if (p == null) return;
    for (final c in p.childProjectIds) {
      if (out.add(c)) walk(c);
    }
  }
  walk(rootId);
  return out;
}

int taskCountForProjectSubtree(
  int rootId,
  List<Project> all,
  List<Task> tasks,
) {
  final ids = descendantProjectIds(rootId, all);
  return tasks
      .where((t) => t.projectId != null && ids.contains(t.projectId))
      .length;
}

/// Top-level folders for browse/pick: projects with no parent in the
/// `has_subproject` tree (requires KGQL `relation` on self-type Project edges).
List<Project> rootProjects(List<Project> projects) {
  return projects.where((p) => p.parentProjectId == null).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
}

List<ProjectBrowseRowVm> projectBrowseRows(
  List<Project> allProjects,
  List<Task> allTasks,
) {
  final roots = rootProjects(allProjects);
  return roots.map((p) {
    final subCount = p.childProjectIds.length;
    final taskCount = taskCountForProjectSubtree(p.id, allProjects, allTasks);
    final subtitle = subCount > 0
        ? '$subCount sub-project${subCount == 1 ? '' : 's'} · $taskCount task${taskCount == 1 ? '' : 's'}'
        : '$taskCount task${taskCount == 1 ? '' : 's'}';
    return ProjectBrowseRowVm(
      project: p,
      subProjectCount: subCount,
      taskCountInSubtree: taskCount,
      subtitle: subtitle,
    );
  }).toList();
}

final projectBrowseRowsProvider =
    FutureProvider<List<ProjectBrowseRowVm>>((ref) async {
  await ref.watch(authenticatedUserProvider.future);
  final projects = await ref.watch(allProjectsProvider.future);
  final tasks = await ref.watch(allTasksProvider.future);
  return projectBrowseRows(projects, tasks);
});
