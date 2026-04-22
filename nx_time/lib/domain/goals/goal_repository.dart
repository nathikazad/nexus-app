import 'package:nx_time/domain/goals/action_goal.dart';
import 'package:nx_time/domain/goals/expense_goal.dart';

/// Read-side contract for `app` goal orchestrators.
abstract class GoalRepository {
  Future<ActionGoalsWeek> getActionGoalsWeek({
    required DateTime weekStart,
    int? goalId,
  });

  Future<ActionGoalsTrend> getActionGoalsTrend({
    required int goalId,
    required int weeks,
  });

  Future<ExpenseGoalsMonth> getExpenseGoalsMonth({
    required DateTime monthStart,
    int? goalId,
  });
}
