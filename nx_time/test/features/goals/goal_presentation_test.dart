import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/goals.dart' as wire;
import 'package:nx_time/data/goals/goal_mapper.dart';
import 'package:nx_time/domain/goals/action_goal.dart';
import 'package:nx_time/domain/goals/goal_day_state.dart';
import 'package:nx_time/features/goals/goal_presentation.dart';

ActionGoalWeekItem goal(
  int id, {
  int? routine,
  List<String> days = const ['friday', 'saturday'],
  String start = '09:00',
  String end = '10:00',
  String selected = 'start_time',
  String evaluation = 'aggregate',
}) => actionGoalsWeekFromWire(
  wire.ActionGoalWeekResponse.fromJson({
    'week_start': '2026-10-26',
    'items': [
      {
        'id': id,
        'routine_id': routine,
        'label': 'Goal $id',
        'cadence': 'daily',
        'model_type': 'Sleep',
        'selected_attribute': selected,
        'evaluation': evaluation,
        'aggregation': 'count',
        'target': {'op': '>=', 'value': 1},
        'daily_state': [],
        'streak': {},
        'schedule': {
          'entries': [
            {'days': days, 'start_time': start, 'end_time': end},
          ],
        },
      },
    ],
  }),
).items.single;
void main() {
  test(
    'restriction days keep today pending and past no-violation days green',
    () {
      final item = goal(1, days: ['tuesday'], evaluation: 'restrictions');
      final now = DateTime(2026, 10, 30, 18);
      expect(goalDayMarker(item, GoalDailyState(date: DateTime(2026, 10, 29), state: GoalDayState.hit), now), GoalDayMarker.met);
      expect(
        goalDayMarker(
          item,
          GoalDailyState(date: now, state: GoalDayState.hit),
          now,
        ),
        GoalDayMarker.pending,
      );
      expect(
        goalDayMarker(
          item,
          GoalDailyState(date: now, state: GoalDayState.miss),
          now,
        ),
        GoalDayMarker.missed,
      );
      expect(
        goalDayMarker(
          item,
          GoalDailyState(date: DateTime(2026, 10, 31), state: GoalDayState.hit),
          now,
        ),
        GoalDayMarker.pending,
      );
    },
  );

  test(
    'server date cannot mark tomorrow elapsed or include it in consistency',
    () {
      final score = ActionGoalsMonthScore(
        monthStart: DateTime(2026, 10),
        consistency: const ActionGoalMonthConsistency(
          hit: 3,
          total: 12,
          ratio: .25,
        ),
        days: [
          ActionGoalMonthScoreDay(
            date: DateTime(2026, 10, 30),
            hit: 3,
            total: 6,
            ratio: .5,
            future: false,
          ),
          ActionGoalMonthScoreDay(
            date: DateTime(2026, 10, 31),
            hit: 0,
            total: 6,
            ratio: 0,
            future: false,
          ),
        ],
      );
      final local = monthScoreForLocalDate(score, DateTime(2026, 10, 30, 18));
      expect(local.days.last.future, isTrue);
      expect(local.consistency.total, 6);
      expect(local.consistency.ratio, .5);
      final tomorrow = monthScoreForLocalDate(local, DateTime(2026, 10, 31));
      expect(tomorrow.days.last.future, isFalse);
      expect(tomorrow.consistency.total, 12);
    },
  );

  test('saved goal IDs determine order without grouping or clock sorting', () {
    final items = [
      goal(1, routine: 10),
      goal(2, routine: 20),
      goal(3, routine: 10),
      goal(4),
    ];
    expect(sortGoalsByPreference(items, [3, 2, 1]).map((g) => g.id), [
      3,
      2,
      1,
      4,
    ]);
    expect(
      sortGoalsByPreference(items, [99, 2, 2, 'invalid']).map((g) => g.id),
      [2, 1, 3, 4],
    );
    expect(sortGoalsByPreference(items, null).map((g) => g.id), [1, 2, 3, 4]);
  });
  test('clock for scheduled future days and before today’s planned start', () {
    final item = goal(1, routine: 10);
    expect(item.routineId, 10);
    GoalDailyState day(int d, GoalDayState state) =>
        GoalDailyState(date: DateTime(2026, 10, d), state: state);
    expect(
      goalDayMarker(
        item,
        day(31, GoalDayState.pending),
        DateTime(2026, 10, 30, 16),
      ),
      GoalDayMarker.planned,
    );
    expect(
      goalDayMarker(
        item,
        day(30, GoalDayState.pending),
        DateTime(2026, 10, 30, 8),
      ),
      GoalDayMarker.planned,
    );
    expect(
      goalDayMarker(
        item,
        day(30, GoalDayState.pending),
        DateTime(2026, 10, 30, 16),
      ),
      GoalDayMarker.missed,
    );
    expect(
      goalDayMarker(item, day(30, GoalDayState.hit), DateTime(2026, 10, 30, 8)),
      GoalDayMarker.met,
    );
    expect(
      goalDayMarker(item, day(31, GoalDayState.notDue), DateTime(2026, 10, 30)),
      GoalDayMarker.off,
    );
  });
  test('unscheduled days are dashes unless their goal was met', () {
    final item = goal(1, days: ['tuesday']);
    final now = DateTime(2026, 10, 30, 16);
    expect(
      goalDayMarker(
        item,
        GoalDailyState(date: now, state: GoalDayState.miss),
        now,
      ),
      GoalDayMarker.off,
    );
    expect(
      goalDayMarker(
        item,
        GoalDailyState(date: now, state: GoalDayState.hit),
        now,
      ),
      GoalDayMarker.met,
    );
  });
  test('no planned clock on an unscheduled future day', () {
    expect(
      goalDayMarker(
        goal(1, days: ['tuesday']),
        GoalDailyState(
          date: DateTime(2026, 10, 31),
          state: GoalDayState.pending,
        ),
        DateTime(2026, 10, 30),
      ),
      GoalDayMarker.off,
    );
  });
}
