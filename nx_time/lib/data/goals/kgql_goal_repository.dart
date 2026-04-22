import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/goals.dart' as nx;

import 'package:nx_time/data/goals/goal_mapper.dart';
import 'package:nx_time/domain/goals/action_goal.dart';
import 'package:nx_time/domain/goals/expense_goal.dart';
import 'package:nx_time/domain/goals/goal_repository.dart';

class KgqlGoalRepository implements GoalRepository {
  KgqlGoalRepository({required GraphQLClient client}) : _client = client;

  final GraphQLClient _client;

  @override
  Future<ActionGoalsWeek> getActionGoalsWeek({
    required DateTime weekStart,
    int? goalId,
  }) async {
    final w = await nx.fetchActionGoalsWeek(
      _client,
      weekStart: weekStart,
      goalId: goalId,
    );
    return actionGoalsWeekFromWire(w);
  }

  @override
  Future<ActionGoalsTrend> getActionGoalsTrend({
    required int goalId,
    required int weeks,
  }) async {
    final w = await nx.fetchActionGoalsTrend(
      _client,
      goalId: goalId,
      weeks: weeks,
    );
    return actionGoalsTrendFromWire(
      w,
      requestedGoalId: goalId,
      requestedWeeks: weeks,
    );
  }

  @override
  Future<ExpenseGoalsMonth> getExpenseGoalsMonth({
    required DateTime monthStart,
    int? goalId,
  }) async {
    final w = await nx.fetchExpenseGoalsMonth(
      _client,
      monthStart: monthStart,
      goalId: goalId,
    );
    return expenseGoalsMonthFromWire(w);
  }
}
