import 'package:flutter_test/flutter_test.dart';
import 'package:nx_projects/domain/task/task.dart';
import 'package:nx_projects/features/sprint/sprint_actual_hours.dart';

void main() {
  test('taskActualHoursForDay sums linked Work actions on that day', () {
    final task = Task(
      id: 1,
      title: 'OTA',
      workLinks: [
        TaskWorkLink(
          relationId: 10,
          workActionId: 100,
          workActionName: 'Work',
          startTime: DateTime(2026, 5, 5, 17, 50),
          endTime: DateTime(2026, 5, 5, 20, 14),
          timeSpentHours: 2,
        ),
        TaskWorkLink(
          relationId: 11,
          workActionId: 101,
          workActionName: 'Work',
          startTime: DateTime(2026, 5, 5, 9),
          endTime: DateTime(2026, 5, 5, 10, 30),
        ),
        TaskWorkLink(
          relationId: 12,
          workActionId: 102,
          workActionName: 'Work',
          startTime: DateTime(2026, 5, 6, 9),
          endTime: DateTime(2026, 5, 6, 12),
        ),
      ],
    );

    expect(taskActualHoursForDay(task, '2026-05-05'), 3.5);
    expect(taskActualHoursBeforeDay(task, '2026-05-05'), 0);
    expect(taskActualHoursBeforeDay(task, '2026-05-06'), 3.5);
    expect(taskActualHoursForDay(task, '2026-05-06'), 3);
  });
}
