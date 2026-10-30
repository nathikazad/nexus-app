import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/domain/goals/goal_evaluation.dart';
import 'package:nx_time/domain/goals/goal_day_state.dart';
import 'package:nx_time/domain/schedules/schedule_plan.dart';
import 'package:nx_time/features/routine/routine_data.dart';
import 'package:nx_time/dev/fixture_data.dart';

void main() {
  test(
    'ten days of real backend results, four linked schedules and an independent plan',
    () {
      final d = previewRoutine();
      expect(d.goals.length, 5);
      expect(d.plans.length, 5);
      expect(d.plans.where((p) => p.goalId != null).length, 4);
      expect(d.goals.expand((g) => g.dailyState).length, 50);
      for (var day = 1; day <= 10; day++) {
        expect(d.windows(DateTime(2026, 6, day)).length, 5);
        for (final g in d.goals) {
          expect(resultOn(g, DateTime(2026, 6, day)), isNotNull);
        }
      }
      final sleep = d.windows(DateTime(2026, 6, 1)).last;
      expect(sleep.start, DateTime(2026, 6, 1, 22));
      expect(sleep.end, DateTime(2026, 6, 2, 6));
      expect(d.windows(DateTime(2026, 5, 31)), isEmpty);
      expect(d.windows(DateTime(2026, 6, 11)), isEmpty);
    },
  );
  test('partial checks stay distinct and pending never becomes a miss', () {
    expect(adherenceLabel(GoalDayState.hit, true, true), 'Both met');
    expect(adherenceLabel(GoalDayState.miss, true, false), 'Start only');
    expect(adherenceLabel(GoalDayState.miss, false, true), 'End only');
    expect(adherenceLabel(GoalDayState.miss, false, false), 'Neither met');
    expect(adherenceLabel(GoalDayState.pending, false, false), 'Pending');
    final d = previewRoutine();
    final gaming = d.goals.singleWhere(
      (g) => g.evaluation == GoalEvaluation.restrictions,
    );
    final noPlay = resultOn(gaming, DateTime(2026, 6, 5))!;
    expect(noPlay.state, GoalDayState.hit);
    expect(noPlay.sessions, isEmpty);
  });
  test('transport offsets preserve entered wall clock', () {
    for (final suffix in ['Z', '+05:30', '-0700', '']) {
      expect(
        goalWallClock('2026-06-01T22:00:00$suffix'),
        DateTime(2026, 6, 1, 22),
      );
    }
  });
  test('multiple windows and omitted day offset', () {
    final p = const SchedulePlan(
      id: 1,
      name: 'Exercise',
      entries: [
        {
          'days': ['monday'],
          'start_time': '11:00',
          'end_time': '11:30',
        },
        {
          'days': ['monday'],
          'start_time': '19:00',
          'end_time': '19:30',
        },
      ],
    );
    final w = p.onDay(DateTime(2026, 6, 1));
    expect(w.map((w) => w.start.hour), [11, 19]);
    expect(w[1].end.day, 1);
    expect(p.onDay(DateTime(2026, 6, 2)), isEmpty);
  });
}
