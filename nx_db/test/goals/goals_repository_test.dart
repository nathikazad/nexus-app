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
      domainId: 3,
      goalId: 101,
    );
    expect(r.items, isEmpty);

    final cap = verify(() => mock.query(captureAny())).captured.single
        as QueryOptions;
    expect(cap.variables?['weekStart'], '2026-04-20');
    expect(cap.variables?['domainId'], 3);
    expect(cap.variables?['goalId'], 101);
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

    await fetchActionGoalsTrend(mock, goalId: 42, weeks: 4, domainId: 2);
    final cap = verify(() => mock.query(captureAny())).captured.single
        as QueryOptions;
    expect(cap.variables?['goalId'], 42);
    expect(cap.variables?['weeks'], 4);
    expect(cap.variables?['domainId'], 2);
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
      domainId: 5,
    );
    final cap = verify(() => mock.query(captureAny())).captured.single
        as QueryOptions;
    expect(cap.variables?['monthStart'], '2026-04-01');
    expect(cap.variables?['domainId'], 5);
    expect(cap.variables?['goalId'], isNull);
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
        domainId: 1,
      ),
      throwsA(isA<OperationException>()),
    );
  });
}
