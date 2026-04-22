import 'package:nx_db/goals.dart' as nx;
import 'package:nx_time/core/time/wall_clock_time.dart';
import 'package:nx_time/domain/goals/action_goal.dart';
import 'package:nx_time/domain/goals/goal_cadence.dart';
import 'package:nx_time/domain/goals/goal_day_state.dart';
import 'package:nx_time/domain/goals/goal_preferred_slot.dart';
import 'package:nx_time/domain/goals/goal_streak.dart';
import 'package:nx_time/domain/goals/goal_threshold.dart';
import 'package:nx_time/domain/goals/expense_goal.dart';

GoalTarget _targetFromWire(nx.GoalTarget t) {
  return GoalTarget(
    op: goalThresholdOpFromKgql(t.op),
    value: t.value,
  );
}

GoalStreakWindow _streakWindowFromWire(nx.GoalStreakWindow w) {
  return GoalStreakWindow(
    streakCount: w.streakCount,
    firstPeriod: w.firstPeriod == null
        ? null
        : asStoredLocalWallClock(w.firstPeriod!),
    lastPeriod: w.lastPeriod == null
        ? null
        : asStoredLocalWallClock(w.lastPeriod!),
  );
}

GoalStreakSummary _streakFromWire(nx.GoalStreakSummary s) {
  return GoalStreakSummary(
    isActive: s.isActive,
    currentPeriodHit: s.currentPeriodHit,
    current: _streakWindowFromWire(s.current),
    max: _streakWindowFromWire(s.max),
  );
}

GoalDayState _dayStateFromWire(nx.GoalDayState s) {
  switch (s) {
    case nx.GoalDayState.hit:
      return GoalDayState.hit;
    case nx.GoalDayState.miss:
      return GoalDayState.miss;
    case nx.GoalDayState.pending:
      return GoalDayState.pending;
  }
}

ActionGoalMeta? _metaFromWire(nx.ActionGoalMeta? m) {
  if (m == null) return null;
  return ActionGoalMeta(
    preferredSlots: m.preferredSlots
        ?.map(
          (s) => GoalPreferredSlot(
            dow: s.dow,
            startTime: s.startTime,
            durationMin: s.durationMin,
            hit: s.hit,
          ),
        )
        .toList(),
    autoGenerateTasks: m.autoGenerateTasks,
  );
}

ActionGoalWeekItem _weekItemFromWire(nx.ActionGoalWeekItem w) {
  return ActionGoalWeekItem(
    id: w.id,
    label: w.label,
    cadence: goalCadenceFromKgql(w.cadence),
    modelType: w.modelType,
    filter: w.filter,
    selectedAttribute: w.selectedAttribute,
    aggregation: w.aggregation,
    metric: w.metric,
    target: _targetFromWire(w.target),
    dailyState: w.dailyState
        .map(
          (d) => GoalDailyState(
            date: asStoredLocalWallClock(d.date),
            state: _dayStateFromWire(d.state),
          ),
        )
        .toList(),
    streak: _streakFromWire(w.streak),
    meta: _metaFromWire(w.meta),
  );
}

ActionGoalsWeek actionGoalsWeekFromWire(nx.ActionGoalWeekResponse w) {
  return ActionGoalsWeek(
    weekStart: asStoredLocalWallClock(w.weekStart),
    items: w.items.map(_weekItemFromWire).toList(),
  );
}

/// When PostGraphile returns the partial `{ "buckets": [] }` shape (goal missing).
ActionGoalsTrend actionGoalsTrendFromWire(
  nx.ActionGoalTrendResponse w, {
  required int requestedGoalId,
  required int requestedWeeks,
}) {
  if (w.goalId == null && w.cadence == null && w.weeks == null) {
    return ActionGoalsTrend.emptyEnvelope(
      requestedGoalId: requestedGoalId,
      requestedWeeks: requestedWeeks,
    );
  }
  return ActionGoalsTrend(
    goalId: w.goalId,
    cadence: w.cadence == null ? null : goalCadenceFromKgql(w.cadence!),
    weeks: w.weeks,
    buckets: w.buckets
        .map(
          (b) => ActionGoalTrendBucket(
            periodStart: asStoredLocalWallClock(b.periodStart),
            successes: b.successes,
            expected: b.expected,
            hit: b.hit,
          ),
        )
        .toList(),
  );
}

ExpenseGoalMonthItem _expenseItemFromWire(nx.ExpenseGoalMonthItem w) {
  return ExpenseGoalMonthItem(
    id: w.id,
    label: w.label,
    cadence: goalCadenceFromKgql(w.cadence),
    modelType: w.modelType,
    filter: w.filter,
    selectedAttribute: w.selectedAttribute,
    aggregation: w.aggregation,
    metric: w.metric,
    target: _targetFromWire(w.target),
    periodValue: w.periodValue,
  );
}

ExpenseGoalsMonth expenseGoalsMonthFromWire(nx.ExpenseGoalMonthResponse w) {
  return ExpenseGoalsMonth(
    monthStart: asStoredLocalWallClock(w.monthStart),
    items: w.items.map(_expenseItemFromWire).toList(),
  );
}
