import 'package:nx_time/domain/goals/goal_cadence.dart';
import 'package:nx_time/domain/goals/goal_day_state.dart';
import 'package:nx_time/domain/goals/goal_preferred_slot.dart';
import 'package:nx_time/domain/goals/goal_streak.dart';
import 'package:nx_time/domain/goals/goal_threshold.dart';

class ActionGoalMeta {
  const ActionGoalMeta({this.preferredSlots, this.autoGenerateTasks});

  final List<GoalPreferredSlot>? preferredSlots;
  final bool? autoGenerateTasks;
}

class ActionGoalWeekItem {
  const ActionGoalWeekItem({
    required this.id,
    required this.label,
    required this.cadence,
    required this.modelType,
    this.filter,
    required this.selectedAttribute,
    required this.aggregation,
    this.metric,
    required this.target,
    required this.dailyState,
    required this.streak,
    this.meta,
  });

  final int id;
  final String label;
  final GoalCadence cadence;
  final String modelType;
  final Map<String, dynamic>? filter;
  final String selectedAttribute;
  final String aggregation;
  final String? metric;
  final GoalTarget target;
  final List<GoalDailyState> dailyState;
  final GoalStreakSummary streak;
  final ActionGoalMeta? meta;
}

class ActionGoalsWeek {
  const ActionGoalsWeek({required this.weekStart, required this.items});

  final DateTime weekStart;
  final List<ActionGoalWeekItem> items;
}

class ActionGoalsMonth {
  const ActionGoalsMonth({required this.monthStart, required this.items});

  final DateTime monthStart;
  final List<ActionGoalWeekItem> items;
}

class ActionGoalMonthScoreDay {
  const ActionGoalMonthScoreDay({
    required this.date,
    required this.hit,
    required this.total,
    required this.ratio,
    required this.future,
  });

  final DateTime date;
  final int hit;
  final int total;
  final double? ratio;
  final bool future;
}

class ActionGoalMonthConsistency {
  const ActionGoalMonthConsistency({
    required this.hit,
    required this.total,
    required this.ratio,
  });

  final int hit;
  final int total;
  final double? ratio;
}

class ActionGoalsMonthScore {
  const ActionGoalsMonthScore({
    required this.monthStart,
    required this.consistency,
    required this.days,
  });

  final DateTime monthStart;
  final ActionGoalMonthConsistency consistency;
  final List<ActionGoalMonthScoreDay> days;
}

class ActionGoalTrendBucket {
  const ActionGoalTrendBucket({
    required this.periodStart,
    required this.successes,
    required this.expected,
    required this.hit,
  });

  final DateTime periodStart;
  final num successes;
  final num expected;
  final bool hit;
}

class ActionGoalsTrend {
  const ActionGoalsTrend({
    required this.goalId,
    required this.cadence,
    required this.weeks,
    required this.buckets,
  });

  /// When the server could not load the goal, these mirror the request so UIs
  /// can show an empty chart without losing context ([`get_action_goals_trend`]
  /// may return only `{ "buckets": [] }`).
  final int? goalId;
  final GoalCadence? cadence;
  final int? weeks;
  final List<ActionGoalTrendBucket> buckets;

  /// Envelope for the "goal not found" / partial JSON case.
  factory ActionGoalsTrend.emptyEnvelope({
    required int requestedGoalId,
    required int requestedWeeks,
  }) {
    return ActionGoalsTrend(
      goalId: requestedGoalId,
      cadence: null,
      weeks: requestedWeeks,
      buckets: const [],
    );
  }
}
