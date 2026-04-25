import 'package:nx_projects/domain/project/project.dart';
import 'package:nx_projects/domain/sprint/sprint.dart';
import 'package:nx_projects/domain/task/task.dart';

class PlannerState {
  const PlannerState({
    required this.projects,
    required this.tasks,
    required this.sprints,
  });

  final List<Project> projects;
  final List<Task> tasks;
  final List<Sprint> sprints;
}
