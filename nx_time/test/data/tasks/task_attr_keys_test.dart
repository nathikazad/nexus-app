import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/data/projects/project_attr_keys.dart';
import 'package:nx_time/data/tasks/task_attr_keys.dart';

void main() {
  test('task keys are stable', () {
    expect(kTaskModelTypeName, 'Task');
    expect(kTaskAttrStatus, 'status');
    expect(kTaskAttrHistory, 'history');
    expect(kTaskAttrDueAt, 'due_at');
    expect(kTaskAttrCompletedAt, 'completed_at');
    expect(kTaskRelationKey, 'Task');
    expect(kProjectRelationKey, 'Project');
  });
}
