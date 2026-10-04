import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/data/sync/time_graph.dart';

void main() {
  test('overdue tasks remain current without moving their calendar date', () {
    final graph = TimeGraph([
      {
        'id': 1,
        'kind': 'Feature',
        'families': ['Task'],
        'due_at': '2026-10-01T12:00:00',
        'status': 'todo',
      },
    ]);
    final feed = graph.calendar(DateTime(2026, 10, 3), DateTime(2026, 10, 4));
    expect(feed['entries'], isEmpty);
    expect((feed['current_tasks'] as List).single['id'], 1);
    expect(graph.query({'model_type': 'Task'}, {}).single['id'], 1);
  });
  test('event attendance deduplicates planned Goto and birthdays recur', () {
    final graph = TimeGraph([
      {'id': 1, 'kind': 'Event', 'start_time': '2026-10-03T12:00:00'},
      {
        'id': 2,
        'kind': 'Goto',
        'families': ['Action'],
        'planning_status': 'planned',
        'scheduled_start_time': '2026-10-03T12:00:00',
        'relations': [
          {'model_id': 1, 'model_type': 'Event', 'relation_name': 'to_event'},
        ],
      },
      {'id': 3, 'kind': 'Person', 'birthday': '--10-03'},
    ]);
    final entries =
        graph.calendar(DateTime(2026, 10, 3), DateTime(2026, 10, 4))['entries']
            as List;
    expect(entries.map((e) => e['id']).toSet(), {1, 3});
    expect(
      (entries.firstWhere((e) => e['id'] == 1)['attendance'] as List)
          .single['id'],
      2,
    );
  });
  test('completion appears on completed date in history', () {
    final graph = TimeGraph([
      {
        'id': 1,
        'kind': 'Task',
        'status': 'done',
        'due_at': '2026-09-30T12:00:00',
        'completed_at': '2026-10-03T10:00:00',
      },
    ]);
    final feed = graph.calendar(
      DateTime(2026, 10, 3),
      DateTime(2026, 10, 4),
      history: true,
    );
    expect((feed['entries'] as List).single['kind'], 'completion');
    expect(feed['current_tasks'], isEmpty);
  });
}
