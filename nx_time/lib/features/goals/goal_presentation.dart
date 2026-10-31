import 'package:nx_time/domain/goals/goal_evaluation.dart';
import 'package:nx_time/domain/goals/action_goal.dart';
import 'package:nx_time/domain/goals/goal_day_state.dart';

enum GoalDayMarker { met, missed, planned, pending, off }

/// Explicit account preference order. Unlisted goals retain their input order.
List<ActionGoalWeekItem> sortGoalsByPreference(
  List<ActionGoalWeekItem> items,
  dynamic savedOrder,
) {
  final ranks = <int, int>{};
  if (savedOrder is List) {
    for (final id in savedOrder) {
      if (id is int) ranks.putIfAbsent(id, () => ranks.length);
    }
  }
  final indexed = items.asMap().entries.toList();
  indexed.sort((a, b) {
    final order = (ranks[a.value.id] ?? ranks.length).compareTo(
      ranks[b.value.id] ?? ranks.length,
    );
    return order != 0 ? order : a.key.compareTo(b.key);
  });
  return indexed.map((e) => e.value).toList();
}

GoalDayMarker goalDayMarker(
  ActionGoalWeekItem item,
  GoalDailyState day,
  DateTime now,
) {
  if (day.state == GoalDayState.notDue) return GoalDayMarker.off;
  final date = DateTime(day.date.year, day.date.month, day.date.day);
  final today = DateTime(now.year, now.month, now.day);
  // A per-session limit applies every day, regardless of the planning schedule.
  if (item.evaluation == GoalEvaluation.restrictions) {
    if (date.isAfter(today)) return GoalDayMarker.pending;
    if (date == today && day.state != GoalDayState.miss) {
      return GoalDayMarker.pending;
    }
    return switch (day.state) {
      GoalDayState.hit => GoalDayMarker.met,
      GoalDayState.miss => GoalDayMarker.missed,
      _ => GoalDayMarker.pending,
    };
  }
  if (day.state == GoalDayState.hit) return GoalDayMarker.met;
  const names = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];
  final weekday = names[date.weekday - 1];
  final entries = item.schedule?.entries ?? <Map<String, dynamic>>[];
  if (entries.isNotEmpty &&
      !entries.any((e) => (e['days'] as List).contains(weekday))) {
    return GoalDayMarker.off;
  }
  for (final entry in entries) {
    if (!(entry['days'] as List).contains(weekday)) continue;
    final clockKey = item.selectedAttribute == 'end_time'
        ? 'end_time'
        : 'start_time';
    final parts = (entry[clockKey] as String).split(':');
    final planned = DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
    if (planned.isAfter(now)) return GoalDayMarker.planned;
  }
  if (date.isAfter(today)) return GoalDayMarker.pending;
  return GoalDayMarker.missed;
}

num weeklyGoalCount(ActionGoalWeekItem item) => item.dailyState.fold<num>(
  0,
  (sum, day) => sum + (day.value ?? (day.state == GoalDayState.hit ? 1 : 0)),
);

/// Calendar status follows the device's local date, never the server's date.
ActionGoalsMonthScore monthScoreForLocalDate(
  ActionGoalsMonthScore score,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final days = score.days
      .map(
        (day) => ActionGoalMonthScoreDay(
          date: day.date,
          hit: day.hit,
          total: day.total,
          ratio: day.ratio,
          future: DateTime(
            day.date.year,
            day.date.month,
            day.date.day,
          ).isAfter(today),
        ),
      )
      .toList();
  final elapsed = days.where((day) => !day.future);
  final hit = elapsed.fold<int>(0, (sum, day) => sum + day.hit);
  final total = elapsed.fold<int>(0, (sum, day) => sum + day.total);
  return ActionGoalsMonthScore(
    monthStart: score.monthStart,
    days: days,
    consistency: ActionGoalMonthConsistency(
      hit: hit,
      total: total,
      ratio: total == 0 ? null : hit / total,
    ),
  );
}
