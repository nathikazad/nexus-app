import 'package:flutter_test/flutter_test.dart';
import 'package:nx_projects/data/sprints/sprint_mapper.dart';
import 'package:nx_projects/domain/sprint/sprint.dart';
import 'package:nx_projects/domain/sprint/sprint_state.dart';

void main() {
  test('sprint create request mirrors model name to sprint name attribute', () {
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
    expect(attrs['name'], 'Sprint created');
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
    expect(attrs['name'], 'Sprint renamed');
    expect(attrs['goal'], 'Ship planner fixes');
    expect(attrs['status'], 'planned');
    expect(attrs['allocated_hours'], 32);
  });
}
