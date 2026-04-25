import 'package:nx_projects/data/fake/planner_data.dart';
import 'package:nx_projects/data/planner_state.dart';
import 'package:nx_projects/domain/project/project.dart';
import 'package:nx_projects/domain/project/project_repository.dart';
import 'package:nx_projects/domain/sprint/sprint.dart';
import 'package:nx_projects/domain/sprint/sprint_repository.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_repository.dart';
import 'package:riverpod/riverpod.dart';

final plannerProvider = NotifierProvider<Planner, PlannerState>(Planner.new);

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return FakeProjectRepository(ref.read(plannerProvider.notifier));
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return FakeTaskRepository(ref.read(plannerProvider.notifier));
});

final sprintRepositoryProvider = Provider<SprintRepository>((ref) {
  return FakeSprintRepository(ref.read(plannerProvider.notifier));
});

final tasksListProvider = Provider<List<Task>>((ref) {
  return List.unmodifiable(ref.watch(plannerProvider).tasks);
});

final projectsListProvider = Provider<List<Project>>((ref) {
  return List.unmodifiable(ref.watch(plannerProvider).projects);
});

final sprintsListProvider = Provider<List<Sprint>>((ref) {
  return List.unmodifiable(ref.watch(plannerProvider).sprints);
});
