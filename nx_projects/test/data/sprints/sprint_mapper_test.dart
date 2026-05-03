import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_projects/data/sprints/sprint_mapper.dart';
import 'package:nx_projects/domain/sprint/sprint.dart';
import 'package:nx_projects/domain/sprint/sprint_state.dart';

void main() {
  test('sprint reads model name and ignores any legacy name attribute', () {
    final sprint = sprintFromModel(
      Model.fromJson({
        'id': 251,
        'name': 'Model Sprint Name',
        'model_type_id': 1,
        'name_attribute_that_should_not_be_used': 'ignored',
        'attributes': {
          'name': 'Legacy Attribute Name',
          'start_date': '2026-05-01T12:00:00',
          'end_date': '2026-05-07T12:00:00',
          'status': 'planned',
          'allocated_hours': 24,
        },
      }),
    );

    expect(sprint.name, 'Model Sprint Name');
  });

  test('sprint create request writes model name, not a name attribute', () {
    final request = setModelRequestForCreateSprint(
      const Sprint(
        id: 0,
        name: 'Sprint created',
        dates: 'May 1 - May 7',
        badge: 'planned',
        start: '2026-05-01',
        length: 7,
        capH: 24,
        state: SprintState.planned,
      ),
    ).toJson();
    final attrs = {
      for (final attr in request['attributes'] as List<dynamic>)
        (attr as Map<String, dynamic>)['key']: attr['value'],
    };

    expect(request['model_type'], 'Sprint');
    expect(request['name'], 'Sprint created');
    expect(attrs.containsKey('name'), isFalse);
  });

  test('sprint update request includes model name and editable attributes', () {
    final request = setModelRequestForUpdateSprint(
      const Sprint(
        id: 251,
        name: 'Sprint renamed',
        dates: 'May 1 - May 7',
        badge: 'planned',
        start: '2026-05-01',
        length: 7,
        capH: 32,
        state: SprintState.planned,
        goal: 'Ship planner fixes',
      ),
    ).toJson();
    final attrs = {
      for (final attr in request['attributes'] as List<dynamic>)
        (attr as Map<String, dynamic>)['key']: attr['value'],
    };

    expect(request['id'], 251);
    expect(request['name'], 'Sprint renamed');
    expect(attrs.containsKey('name'), isFalse);
    expect(attrs['goal'], 'Ship planner fixes');
    expect(attrs['status'], 'planned');
    expect(attrs['allocated_hours'], 32);
  });
}
