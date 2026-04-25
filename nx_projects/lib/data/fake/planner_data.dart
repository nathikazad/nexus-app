import 'package:nx_projects/data/fake/seed_data.dart';
import 'package:nx_projects/data/planner_state.dart';
import 'package:nx_projects/domain/project/project.dart';
import 'package:nx_projects/domain/project/project_repository.dart';
import 'package:nx_projects/domain/sprint/sprint.dart';
import 'package:nx_projects/domain/sprint/sprint_repository.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/domain/task/task_repository.dart';
import 'package:riverpod/riverpod.dart';

/// Holds projects, tasks, sprints; all mutations go through this notifier.
class Planner extends Notifier<PlannerState> {
  @override
  PlannerState build() {
    return PlannerState(
      projects: List.from(buildSeedProjects()),
      tasks: List.from(buildSeedTasks()),
      sprints: List.from(buildSeedSprints()),
    );
  }

  void _set(PlannerState next) => state = next;

  void addProject(Project project) {
    _set(PlannerState(
      projects: [...state.projects, project],
      tasks: state.tasks,
      sprints: state.sprints,
    ));
  }

  void upsertTask(Task task) {
    final i = state.tasks.indexWhere((t) => t.id == task.id);
    final next = List<Task>.from(state.tasks);
    if (i < 0) {
      next.insert(0, task);
    } else {
      next[i] = task;
    }
    _set(PlannerState(
      projects: state.projects,
      tasks: next,
      sprints: state.sprints,
    ));
  }

  void deleteTask(String id) {
    _set(PlannerState(
      projects: state.projects,
      tasks: state.tasks.where((t) => t.id != id).toList(),
      sprints: state.sprints,
    ));
  }

  List<Project> readRootProjects() =>
      state.projects.where((e) => e.parentId == null).toList();

  Project? readProject(String id) {
    for (final p in state.projects) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<Project> readSubProjects(String parentId) =>
      state.projects.where((e) => e.parentId == parentId).toList();

  List<Task> readTasks() => List.unmodifiable(state.tasks);

  Task? readTask(String id) {
    for (final t in state.tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  List<Sprint> readSprints() => List.unmodifiable(state.sprints);

  Sprint? readSprint(int id) {
    for (final s in state.sprints) {
      if (s.id == id) return s;
    }
    return null;
  }
}

class FakeProjectRepository implements ProjectRepository {
  FakeProjectRepository(this._planner);
  final Planner _planner;

  @override
  Future<List<Project>> listRootProjects() async => _planner.readRootProjects();

  @override
  Future<Project?> getProject(String id) async => _planner.readProject(id);

  @override
  Future<List<Project>> getSubProjects(String parentId) async =>
      _planner.readSubProjects(parentId);

  @override
  Future<Project> addProject(Project project) async {
    _planner.addProject(project);
    return project;
  }

  @override
  Future<Project> addSubProject(String parentId, Project sub) async {
    final s = sub.copyWith(parentId: parentId);
    return addProject(s);
  }
}

class FakeTaskRepository implements TaskRepository {
  FakeTaskRepository(this._planner);
  final Planner _planner;

  @override
  Future<List<Task>> listAll() async => _planner.readTasks();

  @override
  Future<Task?> getById(String id) async => _planner.readTask(id);

  @override
  Future<Task> upsert(Task task) async {
    _planner.upsertTask(task);
    return task;
  }

  @override
  Future<void> delete(String id) async {
    _planner.deleteTask(id);
  }
}

class FakeSprintRepository implements SprintRepository {
  FakeSprintRepository(this._planner);
  final Planner _planner;

  @override
  Future<List<Sprint>> listSprints() async => _planner.readSprints();

  @override
  Future<Sprint?> getById(int id) async => _planner.readSprint(id);
}
