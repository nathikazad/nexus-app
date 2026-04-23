import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/domain/action/action.dart';
import 'package:nx_time/domain/goals/action_goal.dart';
import 'package:nx_time/domain/goals/goal_cadence.dart';
import 'package:nx_time/domain/goals/goal_streak.dart';
import 'package:nx_time/domain/goals/goal_threshold.dart';
import 'package:nx_time/domain/action/week_actions.dart';
import 'package:nx_time/features/goals/goal_detail/goal_action_helpers.dart';

ActionGoalWeekItem _dummyItem({
  required String modelType,
  String selectedAttribute = 'end_time',
  String? metric,
}) {
  return ActionGoalWeekItem(
    id: 1,
    label: 't',
    cadence: GoalCadence.daily,
    modelType: modelType,
    filter: null,
    selectedAttribute: selectedAttribute,
    aggregation: 'sum',
    metric: metric,
    target: const GoalTarget(op: GoalThresholdOp.gte, value: 8 * 3600),
    dailyState: const [],
    streak: const GoalStreakSummary(
      isActive: true,
      currentPeriodHit: false,
      current: GoalStreakWindow(streakCount: 0),
      max: GoalStreakWindow(streakCount: 0),
    ),
    meta: null,
  );
}

void main() {
  test('durationOf uses cap when end is null', () {
    final a = Action(
      id: 1,
      name: 'a',
      modelTypeId: 1,
      modelTypeName: 'Sleep',
      startTime: DateTime(2026, 4, 22, 10, 0),
      endTime: null,
    );
    final cap = DateTime(2026, 4, 22, 12, 30);
    final d = durationOf(
      a,
      cap: cap,
      now: DateTime(2026, 4, 22, 20, 0),
    );
    expect(d, const Duration(hours: 2, minutes: 30));
  });

  test('sumDurationForDay sums only actions on that calendar day (attribution)', () {
    final mon = DateTime(2026, 4, 20);
    final a1 = Action(
      id: 1,
      name: 'a1',
      modelTypeId: 1,
      modelTypeName: 'Sleep',
      startTime: DateTime(2026, 4, 20, 1, 0),
      endTime: DateTime(2026, 4, 20, 8, 0),
    );
    final a2 = Action(
      id: 2,
      name: 'a2',
      modelTypeId: 1,
      modelTypeName: 'Sleep',
      startTime: DateTime(2026, 4, 21, 0, 0),
      endTime: DateTime(2026, 4, 21, 7, 0),
    );
    final wa = WeekActions(
      weekStart: mon,
      byDay: const [],
      all: [a1, a2],
    );
    final s0 = sumDurationForDay(wa, [a1, a2], 0, selectedAttribute: 'end_time');
    expect(s0, const Duration(hours: 7));
    final s1 = sumDurationForDay(wa, [a1, a2], 1, selectedAttribute: 'end_time');
    expect(s1, const Duration(hours: 7));
  });

  test('todayAttributedTime is null when the viewed week is not current', () {
    final mon = DateTime(2020, 1, 6);
    final t = DateTime(2020, 1, 6, 7);
    final a = Action(
      id: 1,
      name: 'a',
      modelTypeId: 1,
      modelTypeName: 'Sleep',
      startTime: DateTime(2020, 1, 5, 22, 0),
      endTime: t,
    );
    final wa = WeekActions(weekStart: mon, byDay: const [], all: [a]);
    expect(todayAttributedTime(wa, _dummyItem(modelType: 'Sleep')), isNull);
  });
}
