import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/domain/tasks/task.dart';
import 'package:nx_time/domain/tasks/task_status.dart';

void main() {
  test('Task equality includes status and history', () {
    const a = Task(
      id: 1,
      name: 'A',
      modelTypeId: 9,
      status: TaskStatus.progress,
      history: [
        {'at': '2026-10-01T10:00:00Z', 'status': 'todo'},
      ],
    );
    const b = Task(
      id: 1,
      name: 'A',
      modelTypeId: 9,
      status: TaskStatus.progress,
      history: [
        {'at': '2026-10-01T10:00:00Z', 'status': 'todo'},
      ],
    );
    const c = Task(
      id: 1,
      name: 'A',
      modelTypeId: 9,
      status: TaskStatus.done,
      history: [
        {'at': '2026-10-01T10:00:00Z', 'status': 'todo'},
      ],
    );
    expect(a, b);
    expect(a, isNot(c));
  });

  test('Task.copyWith overrides fields', () {
    const t = Task(
      id: 1,
      name: 'A',
      modelTypeId: 9,
      status: TaskStatus.todo,
      history: [
        {'at': '2026-10-01T10:00:00Z', 'status': 'todo'},
      ],
    );
    final u = t.copyWith(name: 'B', status: TaskStatus.done);
    expect(u.name, 'B');
    expect(u.status, TaskStatus.done);
    expect(u.history, t.history);
    expect(u.id, 1);
  });

  test('TaskActivityLink equality', () {
    const x = TaskActivityLink(
      activityId: 10,
      activityModelTypeName: 'Meet',
      relationId: 99,
    );
    const y = TaskActivityLink(
      activityId: 10,
      activityModelTypeName: 'Meet',
      relationId: 99,
    );
    expect(x, y);
  });
}
