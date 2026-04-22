@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/goals.dart';
import 'package:test/test.dart' show Tags;

void main() {
  group('goals documents parse with gql()', () {
    test('getActionGoalsWeek', () {
      gql(getActionGoalsWeekQuery);
      expect(getActionGoalsWeekQuery, contains(r'$weekStart'));
      expect(getActionGoalsWeekQuery, contains(r'GetActionGoalsWeek'));
      expect(getActionGoalsWeekQuery, contains('getActionGoalsWeek'));
      expect(getActionGoalsWeekQuery, contains('Date!'));
    });

    test('getActionGoalsTrend', () {
      gql(getActionGoalsTrendQuery);
      expect(getActionGoalsTrendQuery, contains(r'$goalId'));
      expect(getActionGoalsTrendQuery, contains(r'Int!'));
      expect(getActionGoalsTrendQuery, contains('getActionGoalsTrend'));
    });

    test('getExpenseGoalsMonth', () {
      gql(getExpenseGoalsMonthQuery);
      expect(getExpenseGoalsMonthQuery, contains(r'$monthStart'));
      expect(getExpenseGoalsMonthQuery, contains('getExpenseGoalsMonth'));
    });
  });
}
