import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../core/json/payload_unwrap.dart';
import 'documents/get_action_goals_trend.graphql.dart';
import 'documents/get_action_goals_week.graphql.dart';
import 'documents/get_expense_goals_month.graphql.dart';
import 'models/action_goal_trend.dart';
import 'models/action_goal_week.dart';
import 'models/expense_goal_month.dart';

/// `Date` GraphQL variable as `YYYY-MM-DD`.
String formatGraphqlDate(DateTime d) {
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

@visibleForTesting
ActionGoalWeekResponse parseGetActionGoalsWeekResult(
  dynamic raw, {
  required DateTime weekStart,
}) {
  final map = unwrapJsonMap(raw);
  if (map == null) {
    return ActionGoalWeekResponse.emptyForWeek(weekStart);
  }
  return ActionGoalWeekResponse.fromJson(map);
}

@visibleForTesting
ActionGoalTrendResponse parseGetActionGoalsTrendResult(dynamic raw) {
  final map = unwrapJsonMap(raw);
  if (map == null) {
    return ActionGoalTrendResponse.bucketsOnlyEmpty();
  }
  return ActionGoalTrendResponse.fromJson(map);
}

@visibleForTesting
ExpenseGoalMonthResponse parseGetExpenseGoalsMonthResult(
  dynamic raw, {
  required DateTime monthStart,
}) {
  final map = unwrapJsonMap(raw);
  if (map == null) {
    return ExpenseGoalMonthResponse.emptyForMonth(monthStart);
  }
  return ExpenseGoalMonthResponse.fromJson(map);
}

/// Calls [getActionGoalsWeek] via GraphQL (PostGraphile `app.get_action_goals_week`).
Future<ActionGoalWeekResponse> fetchActionGoalsWeek(
  GraphQLClient client, {
  required DateTime weekStart,
  required int domainId,
  int? goalId,
}) async {
  final result = await client.query(
    QueryOptions(
      document: gql(getActionGoalsWeekQuery),
      variables: {
        'weekStart': formatGraphqlDate(weekStart),
        'domainId': domainId,
        'goalId': goalId,
      },
      fetchPolicy: FetchPolicy.networkOnly,
    ),
  );

  if (result.hasException) {
    throw result.exception!;
  }

  return parseGetActionGoalsWeekResult(
    result.data?['getActionGoalsWeek'],
    weekStart: weekStart,
  );
}

/// Calls [getActionGoalsTrend] via GraphQL.
Future<ActionGoalTrendResponse> fetchActionGoalsTrend(
  GraphQLClient client, {
  required int goalId,
  required int weeks,
  required int domainId,
}) async {
  final result = await client.query(
    QueryOptions(
      document: gql(getActionGoalsTrendQuery),
      variables: {
        'goalId': goalId,
        'weeks': weeks,
        'domainId': domainId,
      },
      fetchPolicy: FetchPolicy.networkOnly,
    ),
  );

  if (result.hasException) {
    throw result.exception!;
  }

  return parseGetActionGoalsTrendResult(result.data?['getActionGoalsTrend']);
}

/// Calls [getExpenseGoalsMonth] via GraphQL.
Future<ExpenseGoalMonthResponse> fetchExpenseGoalsMonth(
  GraphQLClient client, {
  required DateTime monthStart,
  required int domainId,
  int? goalId,
}) async {
  final result = await client.query(
    QueryOptions(
      document: gql(getExpenseGoalsMonthQuery),
      variables: {
        'monthStart': formatGraphqlDate(monthStart),
        'domainId': domainId,
        'goalId': goalId,
      },
      fetchPolicy: FetchPolicy.networkOnly,
    ),
  );

  if (result.hasException) {
    throw result.exception!;
  }

  return parseGetExpenseGoalsMonthResult(
    result.data?['getExpenseGoalsMonth'],
    monthStart: monthStart,
  );
}
