import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_projects/data/tasks/task_mapper.dart';

void main() {
  test('taskFromModel maps Work links with relation attributes', () {
    final task = taskFromModel(
      Model.fromJson({
        'id': 12,
        'name': 'Fix sprint work links',
        'model_type_id': 9,
        'model_type': {'id': 9, 'name': 'Feature', 'type_kind': 'base'},
        'status': 'todo',
        'estimate_hours': 3,
        'Work': [
          {
            'id': 900,
            'name': 'Morning work block',
            'start_time': '2026-04-22T10:00:00',
            'end_time': '2026-04-22T11:30:00',
          },
        ],
        'relations': [
          {
            'relation_id': 77,
            'model_id': 900,
            'model_type': 'Work',
            'name': 'Morning work block',
            'relation_attributes': [
              {'key': 'work_description', 'value': 'Mapped relation attrs'},
              {'key': 'time_spent_hours', 'value': '1.5'},
            ],
          },
        ],
      }),
    );

    expect(task.workLinks, hasLength(1));
    expect(task.workLinks.single.relationId, 77);
    expect(task.workLinks.single.workActionId, 900);
    expect(task.workLinks.single.workActionName, 'Morning work block');
    expect(task.workLinks.single.startTime, DateTime(2026, 4, 22, 10));
    expect(task.workLinks.single.endTime, DateTime(2026, 4, 22, 11, 30));
    expect(task.workLinks.single.workDescription, 'Mapped relation attrs');
    expect(task.workLinks.single.timeSpentHours, 1.5);
  });

  test('task fetch struct requests relation attributes', () {
    final struct = buildTaskFetchStruct(
      ModelType(id: 1, name: 'Feature', typeKind: 'base', attributes: const []),
    );

    expect(struct['relations'], isA<Map<String, dynamic>>());
    expect(struct['Work'], {
      'id': true,
      'name': true,
      'start_time': true,
      'end_time': true,
    });
    final relations = struct['relations'] as Map<String, dynamic>;
    expect(relations['relation_id'], isTrue);
    expect(relations['model_id'], isTrue);
    expect(relations['model_type'], isTrue);
    expect(relations['name'], isTrue);
    expect(relations['relation_attributes'], {'key': true, 'value': true});
  });
}
