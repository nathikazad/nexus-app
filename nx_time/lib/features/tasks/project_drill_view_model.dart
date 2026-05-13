import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_time/data/providers.dart';
import 'package:nx_time/domain/projects/project.dart';
import 'package:nx_time/domain/tasks/task.dart';
import 'package:nx_time/features/tasks/task_view_models.dart';

final projectByIdProvider = FutureProvider.family<Project?, int>((
  ref,
  id,
) async {
  await ref.watch(authenticatedUserProvider.future);
  return ref.read(projectRepositoryProvider).getById(id);
});

final subProjectsProvider = FutureProvider.family<List<Project>, int>((
  ref,
  parentId,
) async {
  await ref.watch(authenticatedUserProvider.future);
  final parent = await ref.watch(projectByIdProvider(parentId).future);
  if (parent == null) return [];
  final repo = ref.read(projectRepositoryProvider);
  final out = <Project>[];
  for (final cid in parent.childProjectIds) {
    final c = await repo.getById(cid);
    if (c != null) out.add(c);
  }
  out.sort((a, b) => a.name.compareTo(b.name));
  return out;
});

final tasksInProjectProvider = FutureProvider.family<List<Task>, int>((
  ref,
  projectId,
) async {
  final tasks = await ref.watch(allTasksProvider.future);
  return tasks.where((t) => t.projectId == projectId).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
});

List<Project> breadcrumbForProject(int projectId, List<Project> all) {
  final byId = {for (final p in all) p.id: p};
  final parentOf = <int, int>{};
  for (final p in all) {
    for (final c in p.childProjectIds) {
      parentOf[c] = p.id;
    }
  }
  final chain = <Project>[];
  var cur = projectId;
  final seen = <int>{};
  while (true) {
    if (!seen.add(cur)) break;
    final p = byId[cur];
    if (p == null) break;
    chain.add(p);
    final par = parentOf[cur];
    if (par == null) break;
    cur = par;
  }
  return chain.reversed.toList();
}

final breadcrumbForProjectProvider = FutureProvider.family<List<Project>, int>((
  ref,
  projectId,
) async {
  final all = await ref.watch(allProjectsProvider.future);
  return breadcrumbForProject(projectId, all);
});
