import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/domain/tasks/task.dart';
import 'package:nx_time/domain/tasks/task_status.dart';

void main() {
  test('Task equality includes status and tags', () {
    const a = Task(
      id: 1,
      name: 'A',
      modelTypeId: 9,
      status: TaskStatus.progress,
      tags: ['work'],
    );
    const b = Task(
      id: 1,
      name: 'A',
      modelTypeId: 9,
      status: TaskStatus.progress,
      tags: ['work'],
    );
    const c = Task(
      id: 1,
      name: 'A',
      modelTypeId: 9,
      status: TaskStatus.done,
      tags: ['work'],
    );
    expect(a, b);
    expect(a, isNot(c));
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
