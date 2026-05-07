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
    _set(
      PlannerState(
        projects: [...state.projects, project],
        tasks: state.tasks,
        sprints: state.sprints,
      ),
    );
  }

  void upsertTask(Task task) {
    final i = state.tasks.indexWhere((t) => t.id == task.id);
    final next = List<Task>.from(state.tasks);
    if (i < 0) {
      next.insert(0, task);
    } else {
      next[i] = task;
    }
    _set(
      PlannerState(
        projects: state.projects,
        tasks: next,
        sprints: state.sprints,
      ),
    );
  }

  void deleteTask(int id) {
    _set(
      PlannerState(
        projects: state.projects,
        tasks: state.tasks.where((t) => t.id != id).toList(),
        sprints: state.sprints,
      ),
    );
  }

  List<Project> readRootProjects() =>
      state.projects.where((e) => e.parentId == null).toList();

  Project? readProject(int id) {
    for (final p in state.projects) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<Project> readSubProjects(int parentId) =>
      state.projects.where((e) => e.parentId == parentId).toList();

  List<Task> readTasks() => List.unmodifiable(state.tasks);

  Task? readTask(int id) {
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

  Sprint addSprint(Sprint sprint) {
    final nextId =
        state.sprints.fold<int>(0, (maxId, s) => s.id > maxId ? s.id : maxId) +
        1;
    final created = sprint.copyWith(id: sprint.id == 0 ? nextId : sprint.id);
    _set(
      PlannerState(
        projects: state.projects,
        tasks: state.tasks,
        sprints: [...state.sprints, created],
      ),
    );
    return created;
  }

  void updateSprint(Sprint sprint) {
    final i = state.sprints.indexWhere((s) => s.id == sprint.id);
    if (i < 0) return;
    final next = List<Sprint>.from(state.sprints);
    next[i] = sprint;
    _set(
      PlannerState(projects: state.projects, tasks: state.tasks, sprints: next),
    );
  }

  void setDayNote(int sprintId, String ymd, String value) {
    final s = readSprint(sprintId);
    if (s == null) return;
    final t = value.trim();
    final m = Map<String, String>.from(s.dayNotes);
    if (t.isEmpty) {
      m.remove(ymd);
    } else {
      m[ymd] = t;
    }
    updateSprint(s.copyWith(dayNotes: m));
  }

  /// Schedules a task on [newYmd] (or unschedules when [newYmd] is null).
  /// When moving between days, appends the previous `plannedFor` to `driftFrom`
  /// (deduped, last 5).
  void moveTaskToDay(int taskId, String? newYmd) {
    final t = readTask(taskId);
    if (t == null) return;
    final old = t.plannedFor;
    if (old == newYmd) return;

    var drift = List<String>.from(t.driftFrom);
    if (old != null &&
        newYmd != null &&
        old != newYmd &&
        !drift.contains(old)) {
      drift = [...drift, old];
      if (drift.length > 5) {
        drift = drift.sublist(drift.length - 5);
      }
    }

    upsertTask(
      t.copyWith(
        plannedFor: newYmd,
        clearPlannedFor: newYmd == null,
        driftFrom: drift,
      ),
    );
  }
}

class FakeProjectRepository implements ProjectRepository {
  FakeProjectRepository(this._planner);
  final Planner _planner;

  @override
  Future<List<Project>> listRootProjects() async => _planner.readRootProjects();

  @override
  Future<Project?> getProject(int id) async => _planner.readProject(id);

  @override
  Future<List<Project>> getSubProjects(int parentId) async =>
      _planner.readSubProjects(parentId);

  @override
  Future<Project> addProject(Project project) async {
    _planner.addProject(project);
    return project;
  }

  @override
  Future<Project> addSubProject(int parentId, Project sub) async {
    final s = sub.copyWith(parentId: parentId);
    return addProject(s);
  }
}

class FakeTaskRepository implements TaskRepository {
  FakeTaskRepository(this._planner);
  final Planner _planner;

  static const _workActions = <WorkActionOption>[
    WorkActionOption(
      id: 9001,
      name: 'Morning work block',
      startTime: null,
      endTime: null,
    ),
    WorkActionOption(
      id: 9002,
      name: 'Afternoon work block',
      startTime: null,
      endTime: null,
    ),
  ];

  @override
  Future<List<Task>> listAll() async => _planner.readTasks();

  @override
  Future<Task?> getById(int id) async => _planner.readTask(id);

  @override
  Future<Task> upsert(Task task) async {
    _planner.upsertTask(task);
    return task;
  }

  @override
  Future<void> delete(int id) async {
    _planner.deleteTask(id);
  }

  @override
  Future<List<WorkActionOption>> listWorkActions() async {
    final since = DateTime.now().subtract(const Duration(days: 7));
    return _workActions.where((action) {
      final start = action.startTime;
      return start != null && !start.isBefore(since);
    }).toList();
  }

  @override
  Future<List<WorkActionOption>> listWorkActionsForDay(DateTime day) async {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return _workActions.where((action) {
      final start = action.startTime;
      return start != null &&
          !start.isBefore(dayStart) &&
          start.isBefore(dayEnd);
    }).toList();
  }

  @override
  Future<void> linkWorkAction({
    required int taskId,
    required int workActionId,
    String workDescription = '',
    double? timeSpentHours,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    final task = _planner.readTask(taskId);
    if (task == null) return;
    final action = _workActions.firstWhere(
      (a) => a.id == workActionId,
      orElse: () =>
          WorkActionOption(id: workActionId, name: 'Work #$workActionId'),
    );
    final nextRelationId =
        [
          for (final t in _planner.readTasks())
            for (final w in t.workLinks) w.relationId,
        ].fold<int>(8000, (maxId, id) => id > maxId ? id : maxId) +
        1;
    final link = TaskWorkLink(
      relationId: nextRelationId,
      workActionId: action.id,
      workActionName: action.name,
      startTime: startTime ?? action.startTime,
      endTime: endTime ?? action.endTime,
      relationStartTime: startTime,
      relationEndTime: endTime,
      workDescription: workDescription,
      timeSpentHours: timeSpentHours,
    );
    _planner.upsertTask(task.copyWith(workLinks: [...task.workLinks, link]));
  }

  @override
  Future<void> updateWorkLink({
    required int taskId,
    required int relationId,
    required int workActionId,
    String workDescription = '',
    double? timeSpentHours,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    final task = _planner.readTask(taskId);
    if (task == null) return;
    final links = [
      for (final link in task.workLinks)
        if (link.relationId == relationId)
          _updatedFakeWorkLink(
            link: link,
            workDescription: workDescription,
            timeSpentHours: timeSpentHours,
            startTime: startTime,
            endTime: endTime,
          )
        else
          link,
    ];
    _planner.upsertTask(task.copyWith(workLinks: links));
  }

  TaskWorkLink _updatedFakeWorkLink({
    required TaskWorkLink link,
    required String workDescription,
    required double? timeSpentHours,
    required DateTime? startTime,
    required DateTime? endTime,
  }) {
    WorkActionOption? action;
    for (final candidate in _workActions) {
      if (candidate.id == link.workActionId) {
        action = candidate;
        break;
      }
    }
    final hasRelationTime = startTime != null || endTime != null;
    return TaskWorkLink(
      relationId: link.relationId,
      workActionId: link.workActionId,
      workActionName: link.workActionName,
      startTime: hasRelationTime ? startTime : action?.startTime,
      endTime: hasRelationTime ? endTime : action?.endTime,
      relationStartTime: startTime,
      relationEndTime: endTime,
      workDescription: workDescription,
      timeSpentHours: timeSpentHours,
    );
  }

  @override
  Future<void> deleteWorkLink({
    required int taskId,
    required int relationId,
  }) async {
    final task = _planner.readTask(taskId);
    if (task == null) return;
    _planner.upsertTask(
      task.copyWith(
        workLinks: task.workLinks
            .where((link) => link.relationId != relationId)
            .toList(),
      ),
    );
  }
}

class FakeSprintRepository implements SprintRepository {
  FakeSprintRepository(this._planner);
  final Planner _planner;

  @override
  Future<List<Sprint>> listSprints() async => _planner.readSprints();

  @override
  Future<Sprint?> getById(int id) async => _planner.readSprint(id);

  @override
  Future<Sprint> create(Sprint sprint) async => _planner.addSprint(sprint);

  @override
  Future<void> update(Sprint sprint) async {
    _planner.updateSprint(sprint);
  }
}
