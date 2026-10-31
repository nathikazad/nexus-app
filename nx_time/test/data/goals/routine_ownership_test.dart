import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_time/data/goals/goal_mapper.dart';
import 'package:nx_time/data/sync/time_graph.dart';
import 'package:nx_time/domain/schedules/schedule_plan.dart';

Map<String, dynamic> routine({List<int> goals = const []}) => {
  'id': 90,
  'name': 'Gaming',
  'model_type': 'Play Video Game',
  'start_date': '2026-10-01',
  'end_date': '2026-10-31',
  'Goal': [
    for (final id in goals) {'id': id, 'name': 'Rule'},
  ],
};
Map<String, dynamic> plan(Map<String, dynamic> owner) => {
  'id': 91,
  'name': 'Gaming schedule',
  'entries': [
    {
      'days': ['friday'],
      'start_time': '21:00',
      'end_time': '21:30',
    },
  ],
  'Routine': [owner],
};
void main() {
  test(
    'standalone schedule inherits activity type and validity from Routine',
    () {
      final p = SchedulePlan.fromModel(Model.fromJson(plan(routine())));
      expect(p.modelType, 'Play Video Game');
      expect(p.goalIds, isEmpty);
      expect(p.onDay(DateTime(2026, 10, 30)), hasLength(1));
      expect(p.onDay(DateTime(2026, 11, 6)), isEmpty);
    },
  );
  test(
    'multiple goals share one schedule without choosing an arbitrary goal',
    () {
      final p = SchedulePlan.fromModel(
        Model.fromJson(plan(routine(goals: [1, 2]))),
      );
      expect(p.routineId, 90);
      expect(p.goalIds, [1, 2]);
      expect(p.goalId, isNull);
    },
  );
  test('goal editing retains owner and independent session restrictions', () {
    final g = goalFromModel(
      Model.fromJson({
        'id': 1,
        'name': 'At most thirty minutes',
        'evaluation': 'restrictions',
        'cadence': 'daily',
        'aggregation': 'count',
        'threshold_op': '>=',
        'threshold_value': 1,
        'restrictions': {'max_duration_seconds': 1800},
        'Routine': [
          routine(goals: [1, 2]),
        ],
      }),
    );
    final saved = setModelRequestForUpdateGoal(
      g.copyWith(label: 'Duration'),
    ).toJson();
    final attrs = {for (final a in saved['attributes']) a['key']: a['value']};
    expect(attrs['evaluation'], 'restrictions');
    expect(attrs['restrictions'], {'max_duration_seconds': 1800});
    for (final key in ['model_type', 'filter', 'start_date', 'end_date']) {
      expect(attrs.containsKey(key), isFalse);
    }
    expect(saved['relations'][0]['create'][0]['id'], 90);
    expect(saved['relations'][0]['create'][0].containsKey('name'), isFalse);
    expect(g.routineGoalCount, 2);
  });
  test(
    'offline graph traverses Goal to Routine to Schedule and sibling Goals',
    () {
      final graph = TimeGraph([
        {
          'id': 90,
          'kind': 'Routine',
          ...routine(),
          'relations': [
            {'model_id': 1, 'model_type': 'Goal'},
            {'model_id': 2, 'model_type': 'Goal'},
            {'model_id': 91, 'model_type': 'Schedule'},
          ],
        },
        {'id': 1, 'kind': 'Goal'},
        {'id': 2, 'kind': 'Goal'},
        {'id': 91, 'kind': 'Schedule', 'entries': plan(routine())['entries']},
      ]);
      final projected = graph
          .query(
            {
              'model_type': 'Goal',
              'filters': [
                {'key': 'id', 'op': '=', 'value': 1},
              ],
            },
            {
              'Routine': {
                'Schedule': {'id': true},
                'Goal': {'id': true},
              },
            },
          )
          .single;
      expect(projected['Routine'][0]['Schedule'][0]['id'], 91);
      expect(projected['Routine'][0]['Goal'], hasLength(2));
    },
  );
}
