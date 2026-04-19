import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/domain/tasks/task.dart';
import 'package:nx_time/domain/tasks/task_status.dart';
import 'package:nx_time/features/tasks/task_form_view_model.dart';

void main() {
  test('TaskDraft.canSave requires non-empty name', () {
    expect(TaskDraft().canSave, isFalse);
    expect(TaskDraft(name: '  x  ').canSave, isTrue);
  });

  test('TaskDraft.fromTask and toTaskUpdate', () {
    const t = Task(
      id: 7,
      name: 'N',
      modelTypeId: 9,
      status: TaskStatus.progress,
      tags: ['a'],
      description: 'note',
    );
    final d = TaskDraft.fromTask(t);
    expect(d.name, 'N');
    final u = d.toTaskUpdate(t);
    expect(u.id, 7);
    expect(u.status, TaskStatus.progress);
  });
}
