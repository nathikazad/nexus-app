import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/riverpod.dart';

import 'package:nx_projects/data/projects/kgql_project_repository.dart';
import 'package:nx_projects/data/projects/project_schema_provider.dart';
import 'package:nx_projects/data/sprints/kgql_sprint_repository.dart';
import 'package:nx_projects/data/sprints/sprint_schema_provider.dart';
import 'package:nx_projects/data/tasks/kgql_task_repository.dart';
import 'package:nx_projects/data/tasks/task_schema_provider.dart'
    show
        bugTaskSchemaProvider,
        featureTaskSchemaProvider,
        projectTaskSchemaProvider;
import 'package:nx_projects/domain/project/project.dart';
import 'package:nx_projects/domain/project/project_repository.dart';
import 'package:nx_projects/domain/sprint/sprint.dart';
import 'package:nx_projects/domain/sprint/sprint_repository.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_repository.dart';

export 'package:nx_db/riverpod.dart';

/// KGQL-backed [ProjectRepository].
final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) {
    final personal = ref.watch(personalDomainIdProvider);
    if (personal == null) {
      throw StateError('personalDomainId required (login)');
    }
    return KgqlProjectRepository(
      client: ref.watch(graphqlClientProvider),
      loadProjectSchema: () => ref.read(projectSchemaProvider.future),
      domainId: personal,
    );
  },
);

/// KGQL-backed [TaskRepository] (`ProjectTask` descendants).
final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) {
    final personal = ref.watch(personalDomainIdProvider);
    if (personal == null) {
      throw StateError('personalDomainId required (login)');
    }
    return KgqlTaskRepository(
      client: ref.watch(graphqlClientProvider),
      loadProjectTaskSchema: () => ref.read(projectTaskSchemaProvider.future),
      loadBugSchema: () => ref.read(bugTaskSchemaProvider.future),
      loadFeatureSchema: () => ref.read(featureTaskSchemaProvider.future),
      domainId: personal,
    );
  },
);

/// KGQL-backed [SprintRepository].
final sprintRepositoryProvider = Provider<SprintRepository>(
  (ref) {
    final personal = ref.watch(personalDomainIdProvider);
    if (personal == null) {
      throw StateError('personalDomainId required (login)');
    }
    return KgqlSprintRepository(
      client: ref.watch(graphqlClientProvider),
      loadSprintSchema: () => ref.read(sprintSchemaProvider.future),
      domainId: personal,
    );
  },
);

final projectsListAsyncProvider = FutureProvider<List<Project>>(
  (ref) => ref.watch(projectRepositoryProvider).listRootProjects(),
);

/// All root projects and their direct subprojects in one list (replaces the old flat planner list).
final allProjectsAsyncProvider = FutureProvider<List<Project>>((ref) async {
  // Must watch so this re-runs when [graphqlClientProvider] updates (e.g. auth → session
  // endpoint). Using [read] pinned the first client (defaults) and project fetches could
  // keep hitting the wrong host while task fetches used the updated client.
  final repo = ref.watch(projectRepositoryProvider);
  final roots = await repo.listRootProjects();
  final out = <Project>[];
  for (final r in roots) {
    out.add(r);
    out.addAll(await repo.getSubProjects(r.id));
  }
  return out;
});

final tasksListAsyncProvider = FutureProvider<List<Task>>(
  (ref) => ref.watch(taskRepositoryProvider).listAll(),
);

final sprintsListAsyncProvider = FutureProvider<List<Sprint>>(
  (ref) => ref.watch(sprintRepositoryProvider).listSprints(),
);

/// Sync snapshot: empty list while [FutureProvider] is loading.
final projectsListProvider = Provider<List<Project>>((ref) {
  return ref.watch(allProjectsAsyncProvider).maybeWhen(
        data: (d) => d,
        orElse: () => const <Project>[],
      );
});

final tasksListProvider = Provider<List<Task>>((ref) {
  return ref.watch(tasksListAsyncProvider).maybeWhen(
        data: (d) => d,
        orElse: () => const <Task>[],
      );
});

final sprintsListProvider = Provider<List<Sprint>>((ref) {
  return ref.watch(sprintsListAsyncProvider).maybeWhen(
        data: (d) => d,
        orElse: () => const <Sprint>[],
      );
});
