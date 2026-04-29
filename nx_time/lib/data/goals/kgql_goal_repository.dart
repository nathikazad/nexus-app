import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/goals.dart' as nx;
import 'package:nx_db/kgql.dart';
import 'package:nx_time/data/goals/goal_attr_keys.dart';
import 'package:nx_time/data/goals/goal_mapper.dart';
import 'package:nx_time/domain/goals/action_goal.dart';
import 'package:nx_time/domain/goals/expense_goal.dart';
import 'package:nx_time/domain/goals/goal.dart';
import 'package:nx_time/domain/goals/goal_repository.dart';

class KgqlGoalRepository implements GoalRepository {
  KgqlGoalRepository({
    required GraphQLClient client,
    required Future<ModelType> Function() loadGoalSchema,
    required int domainId,
  })  : _client = client,
        _loadGoalSchema = loadGoalSchema,
        _domainId = domainId;

  final GraphQLClient _client;
  final Future<ModelType> Function() _loadGoalSchema;
  final int _domainId;

  Map<String, dynamic> _goalFetchStruct(ModelType schema) {
    return buildKgqlStructFromSchema(schema);
  }

  @override
  Future<ActionGoalsWeek> getActionGoalsWeek({
    required DateTime weekStart,
    int? goalId,
  }) async {
    final w = await nx.fetchActionGoalsWeek(
      _client,
      weekStart: weekStart,
      domainId: _domainId,
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
      domainId: _domainId,
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
      domainId: _domainId,
      goalId: goalId,
    );
    return expenseGoalsMonthFromWire(w);
  }

  @override
  Future<Goal?> getById(int id) async {
    final schema = await _loadGoalSchema();
    final struct = _goalFetchStruct(schema);
    final m = await fetchKgqlModelById(
      _client,
      modelTypeName: kGoalModelTypeName,
      id: id,
      struct: struct,
      domainId: _domainId,
    );
    return m == null ? null : goalFromModel(m);
  }

  @override
  Future<int> create(Goal goal) {
    return setKgqlModel(_client, setModelRequestForCreateGoal(goal), domainId: _domainId);
  }

  @override
  Future<int> update(Goal goal) {
    return setKgqlModel(_client, setModelRequestForUpdateGoal(goal), domainId: _domainId);
  }

  @override
  Future<void> delete(int id) async {
    await setKgqlModel(_client, setModelRequestForDeleteGoal(id), domainId: _domainId);
  }
}
