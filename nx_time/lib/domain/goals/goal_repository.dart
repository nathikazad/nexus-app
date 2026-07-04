import 'package:nx_time/domain/goals/action_goal.dart';
import 'package:nx_time/domain/goals/expense_goal.dart';
import 'package:nx_time/domain/goals/goal.dart';

/// Read-side + CRUD for `Goal` model rows and read orchestrators.
abstract class GoalRepository {
  Future<ActionGoalsWeek> getActionGoalsWeek({
    required DateTime weekStart,
    int? goalId,
  });

  Future<ActionGoalsMonth> getActionGoalsMonth({
    required DateTime monthStart,
    int? goalId,
  });

  Future<ActionGoalsMonthScore> getActionGoalsMonthScore({
    required DateTime monthStart,
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

  /// Single [Goal] row for edit screen (KGQL get by id + attributes).
  Future<Goal?> getById(int id);

  /// Returns new model id.
  Future<int> create(Goal goal);

  Future<int> update(Goal goal);

  Future<void> delete(int id);
}
