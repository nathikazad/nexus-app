import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/domain/action/action.dart';
import 'package:nx_time/domain/tasks/task.dart';
import 'package:nx_time/domain/tasks/task_status.dart';
import 'package:nx_time/features/tasks/task_detail_view_model.dart';

void main() {
  test('taskDetailVmFromTask computes subtask progress', () {
    const task = Task(
      id: 1,
      name: 'Parent',
      modelTypeId: 9,
      childTaskIds: [2, 3],
    );
    final subtasks = [
      const Task(id: 2, name: 'a', modelTypeId: 9, status: TaskStatus.done),
      const Task(id: 3, name: 'b', modelTypeId: 9, status: TaskStatus.todo),
    ];
    final vm = taskDetailVmFromTask(
      task: task,
      projectSubtitle: 'P › Q',
      subtasks: subtasks,
      linkedActions: const [],
    );
    expect(vm.subtaskDoneCount, 1);
    expect(vm.subtaskTotal, 2);
    expect(vm.subtitle, 'P › Q');
  });

  test('taskDetailVmFromTask maps linked actions', () {
    const task = Task(
      id: 1,
      name: 'T',
      modelTypeId: 9,
      linkedActivities: [
        TaskActivityLink(
          activityId: 100,
          activityModelTypeName: 'Meet',
          relationId: 1,
        ),
      ],
    );
    final act = Action(
      id: 100,
      name: 'Meeting',
      modelTypeId: 5,
      modelTypeName: 'Meet',
      startTime: DateTime(2026, 4, 19, 10),
      endTime: DateTime(2026, 4, 19, 11),
    );
    final vm = taskDetailVmFromTask(
      task: task,
      projectSubtitle: '',
      subtasks: const [],
      linkedActions: [act],
    );
    expect(vm.linkedActivitySummaries.single.title, 'Meeting');
    expect(vm.linkedActivitySummaries.single.action, act);
  });
}
