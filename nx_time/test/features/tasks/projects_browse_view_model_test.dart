import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/domain/projects/project.dart';
import 'package:nx_time/domain/tasks/task.dart';
import 'package:nx_time/domain/tasks/task_status.dart';
import 'package:nx_time/features/tasks/projects_browse_view_model.dart';

void main() {
  test('rootProjects returns only projects with no parent', () {
    final all = [
      const Project(id: 1, name: 'Root', modelTypeId: 8, childProjectIds: [2]),
      const Project(id: 2, name: 'Sub', modelTypeId: 8, parentProjectId: 1),
    ];
    final roots = rootProjects(all);
    expect(roots.map((p) => p.id).toList(), [1]);
  });

  test('rootProjects returns multiple roots for disconnected trees', () {
    final all = [
      const Project(id: 1, name: 'A', modelTypeId: 8, childProjectIds: [2]),
      const Project(id: 2, name: 'B', modelTypeId: 8, parentProjectId: 1),
      const Project(id: 100, name: 'Solo', modelTypeId: 8),
    ];
    final ids = rootProjects(all).map((p) => p.id).toList()..sort();
    expect(ids, [1, 100]);
  });

  test('taskCountForProjectSubtree includes nested project tasks', () {
    final projects = [
      const Project(id: 1, name: 'R', modelTypeId: 8, childProjectIds: [2]),
      const Project(id: 2, name: 'S', modelTypeId: 8),
    ];
    final tasks = [
      const Task(id: 10, name: 'a', modelTypeId: 9, projectId: 2),
      const Task(id: 11, name: 'b', modelTypeId: 9, projectId: 1),
    ];
    expect(taskCountForProjectSubtree(1, projects, tasks), 2);
    expect(taskCountForProjectSubtree(2, projects, tasks), 1);
  });

  test('projectBrowseRows builds subtitle', () {
    final projects = [
      const Project(
        id: 1,
        name: 'R',
        modelTypeId: 8,
        childProjectIds: [2, 3],
      ),
      const Project(id: 2, name: 'A', modelTypeId: 8, parentProjectId: 1),
      const Project(id: 3, name: 'B', modelTypeId: 8, parentProjectId: 1),
    ];
    final tasks = [
      const Task(id: 1, name: 't', modelTypeId: 9, projectId: 2, status: TaskStatus.todo),
    ];
    final rows = projectBrowseRows(projects, tasks);
    expect(rows.single.project.id, 1);
    expect(rows.single.subProjectCount, 2);
    expect(rows.single.subtitle, contains('sub-project'));
  });
}
