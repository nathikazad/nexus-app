import 'package:nx_time/domain/goals/action_goal.dart';
import 'package:nx_time/domain/goals/goal_day_state.dart';
import 'package:nx_time/domain/schedules/schedule_plan.dart';

class RoutineData {
  const RoutineData({
    required this.plans,
    required this.goals,
    this.goalDomains = const {},
  });
  final Map<int, String> goalDomains;
  final List<SchedulePlan> plans;
  final List<ActionGoalWeekItem> goals;
  List<PlanWindow> windows(DateTime date) =>
      plans.expand((p) => p.onDay(date)).toList()
        ..sort((a, b) => a.start.compareTo(b.start));
  ActionGoalWeekItem? goal(int? id) {
    for (final g in goals) {
      if (g.id == id) return g;
    }
    return null;
  }
}

GoalDailyState? resultOn(ActionGoalWeekItem? goal, DateTime date) {
  for (final d in goal?.dailyState ?? <GoalDailyState>[]) {
    if (d.date.year == date.year &&
        d.date.month == date.month &&
        d.date.day == date.day) {
      return d;
    }
  }
  return null;
}
