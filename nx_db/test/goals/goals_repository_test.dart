@Tags(['unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/goals.dart';
import 'package:test/test.dart' show Tags;

import '../_support/mock_graphql_client.dart';

void main() {
  setUpAll(registerGraphqlFallbacks);

  test('fetchActionGoalsWeek passes ISO weekStart and goalId', () async {
    final mock = MockGraphQLClient();
    when(() => mock.query(any())).thenAnswer((_) async => okQueryResult({
          'getActionGoalsWeek': {
            'week_start': '2026-04-20',
            'items': <dynamic>[],
          },
        }));

    final r = await fetchActionGoalsWeek(
      mock,
      weekStart: DateTime.parse('2026-04-20'),
      goalId: 101,
    );
    expect(r.items, isEmpty);

    final cap =
        verify(() => mock.query(captureAny())).captured.single as QueryOptions;
    expect(cap.variables['weekStart'], '2026-04-20');
    expect(cap.variables.containsKey('domainId'), isFalse);
    expect(cap.variables['goalId'], 101);
  });

  test('fetchActionGoalsTrend passes goalId and weeks', () async {
    final mock = MockGraphQLClient();
    when(() => mock.query(any())).thenAnswer((_) async => okQueryResult({
          'getActionGoalsTrend': {
            'goal_id': 1,
            'cadence': 'daily',
            'weeks': 4,
            'buckets': <dynamic>[],
          },
        }));

    await fetchActionGoalsTrend(mock, goalId: 42, weeks: 4);
    final cap =
        verify(() => mock.query(captureAny())).captured.single as QueryOptions;
    expect(cap.variables['goalId'], 42);
    expect(cap.variables['weeks'], 4);
    expect(cap.variables.containsKey('domainId'), isFalse);
  });

  test('fetchActionGoalsMonth passes ISO monthStart and goalId', () async {
    final mock = MockGraphQLClient();
    when(() => mock.query(any())).thenAnswer((_) async => okQueryResult({
          'getActionGoalsMonth': {
            'month_start': '2026-04-01',
            'items': <dynamic>[],
          },
        }));

    final r = await fetchActionGoalsMonth(
      mock,
      monthStart: DateTime.parse('2026-04-01'),
      goalId: 101,
    );
    expect(r.items, isEmpty);

    final cap =
        verify(() => mock.query(captureAny())).captured.single as QueryOptions;
    expect(cap.variables['monthStart'], '2026-04-01');
    expect(cap.variables.containsKey('domainId'), isFalse);
    expect(cap.variables['goalId'], 101);
  });

  test('fetchActionGoalsMonthScore passes ISO monthStart and goalId', () async {
    final mock = MockGraphQLClient();
    when(() => mock.query(any())).thenAnswer((_) async => okQueryResult({
          'getActionGoalsMonthScore': {
            'month_start': '2026-04-01',
            'days': <dynamic>[],
          },
        }));

    final r = await fetchActionGoalsMonthScore(
      mock,
      monthStart: DateTime.parse('2026-04-01'),
      goalId: 101,
    );
    expect(r.days, isEmpty);

    final cap =
        verify(() => mock.query(captureAny())).captured.single as QueryOptions;
    expect(cap.variables['monthStart'], '2026-04-01');
    expect(cap.variables.containsKey('domainId'), isFalse);
    expect(cap.variables['goalId'], 101);
  });

  test('fetchExpenseGoalsMonth passes monthStart and null goalId', () async {
    final mock = MockGraphQLClient();
    when(() => mock.query(any())).thenAnswer((_) async => okQueryResult({
          'getExpenseGoalsMonth': {
            'month_start': '2026-04-01',
            'items': <dynamic>[],
          },
        }));

    await fetchExpenseGoalsMonth(
      mock,
      monthStart: DateTime.parse('2026-04-01'),
    );
    final cap =
        verify(() => mock.query(captureAny())).captured.single as QueryOptions;
    expect(cap.variables['monthStart'], '2026-04-01');
    expect(cap.variables['domainId'], isNull);
    expect(cap.variables['goalId'], isNull);
  });

  test('fetchActionGoalsWeek throws on GraphQL exception', () async {
    final mock = MockGraphQLClient();
    when(() => mock.query(any())).thenAnswer(
      (_) async => QueryResult(
        options: QueryOptions(document: gql('query { __typename }')),
        exception: OperationException(),
        source: QueryResultSource.network,
      ),
    );

    expect(
      () => fetchActionGoalsWeek(
        mock,
        weekStart: DateTime.parse('2026-04-20'),
      ),
      throwsA(isA<OperationException>()),
    );
  });
}
