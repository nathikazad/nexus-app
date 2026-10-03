import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_time/data/projects/project_attr_keys.dart';
import 'package:nx_time/data/tasks/task_attr_keys.dart';
import 'package:nx_time/data/tasks/task_mapper.dart';
import 'package:nx_time/domain/tasks/task.dart';
import 'package:nx_time/domain/tasks/task_status.dart';

void main() {
  test(
    'full edits explicitly clear due date without sending removed attributes',
    () {
      final req = setModelRequestForUpdateTask(
        Task(id: 1, name: 'Laundry', modelTypeId: 1),
        includeAttributes: true,
      );
      final attrs = {for (final a in req.attributes!) a.key: a};
      expect(attrs['due_at']!.delete, isTrue);
      expect(attrs.containsKey('start_time'), isFalse);
      expect(attrs.containsKey('end_time'), isFalse);
      expect(attrs.containsKey('date'), isFalse);
      expect(attrs.containsKey('history'), isFalse);
      expect(attrs.containsKey('completed_at'), isFalse);
    },
  );

  group('taskFromModel', () {
    test('reads status and due date', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'T',
        'model_type_id': 9,
        'status': 'progress',
        'history': [
          {'at': '2026-10-01T10:00:00Z', 'status': 'todo'},
        ],
        'model_type': {'id': 9, 'name': 'Task', 'type_kind': 'base'},
      });
      final t = taskFromModel(m);
      expect(t.status, TaskStatus.progress);
      expect(t.history.single['status'], 'todo');
    });

    test('reads nested Task children', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'Parent',
        'model_type_id': 9,
        'status': 'todo',
        'model_type': {'id': 9, 'name': 'Task', 'type_kind': 'base'},
        'Task': [
          {
            'id': 7,
            'name': 'Child',
            'model_type_id': 9,
            'status': 'todo',
            'model_type': {'id': 9, 'name': 'Task', 'type_kind': 'base'},
          },
        ],
      });
      final t = taskFromModel(m);
      expect(t.childTaskIds, [7]);
    });

    test('reads project from nested Project', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'T',
        'model_type_id': 9,
        'status': 'todo',
        'model_type': {'id': 9, 'name': 'Task', 'type_kind': 'base'},
        'Project': [
          {'id': 42, 'name': 'Auth', 'model_type_id': 8},
        ],
      });
      final t = taskFromModel(m);
      expect(t.projectId, 42);
    });

    test('reads linked activity from relations list', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'T',
        'model_type_id': 9,
        'status': 'todo',
        'model_type': {'id': 9, 'name': 'Task', 'type_kind': 'base'},
        'relations': [
          {'relation_id': 500, 'model_id': 100, 'model_type': 'Meet'},
        ],
      });
      final t = taskFromModel(m);
      expect(t.linkedActivities.length, 1);
      expect(t.linkedActivities.first.activityId, 100);
      expect(t.linkedActivities.first.activityModelTypeName, 'Meet');
      expect(t.linkedActivities.first.relationId, 500);
    });

    test('child tasks and relation ids from relations list', () {
      final m = Model.fromJson({
        'id': 1,
        'name': 'Parent',
        'model_type_id': 9,
        'status': 'todo',
        'model_type': {'id': 9, 'name': 'Task', 'type_kind': 'base'},
        'relations': [
          {'relation_id': 9001, 'model_id': 7, 'model_type': 'Task'},
        ],
      });
      final t = taskFromModel(m);
      expect(t.childTaskIds, [7]);
      expect(t.relationIdByChildTaskId[7], 9001);
    });
  });

  group('setModelRequestForCreateTask', () {
    test('includes attributes and parent + project relations', () {
      final req = setModelRequestForCreateTask(
        Task(
          id: 0,
          name: 'New',
          modelTypeId: 9,
          status: TaskStatus.todo,
          dueAt: DateTime(2026, 10, 2),
        ),
        parentTaskId: 10,
        projectId: 20,
      );
      expect(req.modelType, kTaskModelTypeName);
      final keys = req.attributes!.map((a) => a.key).toSet();
      expect(keys, containsAll([kTaskAttrStatus, kTaskAttrDueAt]));
      expect(req.relations, isNotNull);
      expect(req.relations!.length, 2);
      expect(
        req.relations!.map((r) => r.modelType).toSet(),
        containsAll([kTaskRelationKey, kProjectRelationKey]),
      );
    });
  });

  group('setModelRequestForUpdateTask', () {
    test('passes id and omits attributes by default', () {
      final req = setModelRequestForUpdateTask(
        Task(id: 55, name: 'X', modelTypeId: 9, status: TaskStatus.done),
      );
      expect(req.id, 55);
      expect(req.attributes, isNull);
    });

    test('includeAttributes sends status and due date', () {
      final req = setModelRequestForUpdateTask(
        Task(
          id: 1,
          name: 'Y',
          modelTypeId: 9,
          status: TaskStatus.done,
          dueAt: DateTime(2026, 10, 2),
        ),
        includeAttributes: true,
      );
      final keys = req.attributes!.map((a) => a.key).toSet();
      expect(keys, containsAll([kTaskAttrStatus, kTaskAttrDueAt]));
    });
  });

  test('setModelRequestForDeleteTask', () {
    final req = setModelRequestForDeleteTask(99);
    expect(req.id, 99);
    expect(req.delete, isTrue);
  });
}
