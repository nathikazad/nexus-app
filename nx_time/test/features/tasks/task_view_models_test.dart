import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/domain/projects/project.dart';
import 'package:nx_time/domain/tasks/task.dart';
import 'package:nx_time/domain/tasks/task_status.dart';
import 'package:nx_time/features/tasks/task_view_models.dart';

void main() {
  test('current tasks retain overdue work without moving the due date', () {
    final overdue = Task(
      id: 1,
      name: 'Laundry',
      modelTypeId: 9,
      dueAt: DateTime(2026, 10, 1),
    );
    final tasks = [
      overdue,
      overdue.copyWith(id: 2, status: TaskStatus.progress),
      overdue.copyWith(id: 3, status: TaskStatus.done),
      overdue.copyWith(id: 4, status: TaskStatus.skip),
      overdue.copyWith(id: 5, dueAt: DateTime(2026, 10, 6)),
      overdue.copyWith(id: 6, dueAt: null),
    ];
    expect(currentTasks(tasks, DateTime(2026, 10, 5)).map((t) => t.id), [
      1,
      2,
      6,
    ]);
    expect(overdue.dueAt, DateTime(2026, 10, 1));
  });

  test('taskListSummary counts done vs rest', () {
    final s = taskListSummary([
      const Task(id: 1, name: 'a', modelTypeId: 9, status: TaskStatus.done),
      const Task(id: 2, name: 'b', modelTypeId: 9, status: TaskStatus.todo),
      const Task(id: 3, name: 'c', modelTypeId: 9, status: TaskStatus.progress),
    ]);
    expect(s.total, 3);
    expect(s.doneCount, 1);
    expect(s.todoCount, 2);
  });

  test('projectBreadcrumbLabels builds root › child chain', () {
    final all = [
      const Project(id: 1, name: 'Root', modelTypeId: 8, childProjectIds: [2]),
      const Project(id: 2, name: 'Child', modelTypeId: 8),
    ];
    final m = projectBreadcrumbLabels(all);
    expect(m[2], 'Root › Child');
    expect(m[1], 'Root');
  });

  test('taskRowVmsFromTasks uses breadcrumb map', () {
    final tasks = [const Task(id: 10, name: 'T', modelTypeId: 9, projectId: 2)];
    final vms = taskRowVmsFromTasks(tasks, {2: 'Root › Child'});
    expect(vms.single.subtitle, 'Root › Child');
    expect(vms.single.title, 'T');
  });
}
