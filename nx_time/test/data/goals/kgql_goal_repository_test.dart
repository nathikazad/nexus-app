import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_time/data/goals/kgql_goal_repository.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/domain/goals/goal_cadence.dart';

import '../../_support/mock_graphql_client.dart';

const _week = r'''
{ "week_start": "2026-04-20", "items": [] }
''';

void main() {
  setUpAll(registerGraphqlFallbacks);

  test('getActionGoalsWeek returns empty domain list', () async {
    final mock = MockGraphQLClient();
    when(() => mock.query(any())).thenAnswer(
      (_) async => okQueryResult({
        'getActionGoalsWeek': json.decode(_week),
      }),
    );
    final container = ProviderContainer(
      overrides: [graphqlClientProvider.overrideWithValue(mock)],
    );
    addTearDown(container.dispose);
    final repo = container.read(goalRepositoryProvider);
    final w = await repo.getActionGoalsWeek(weekStart: DateTime(2026, 4, 20));
    expect(w.items, isEmpty);
  });

  test('KgqlGoalRepository getActionGoalsTrend', () async {
    final mock = MockGraphQLClient();
    when(() => mock.query(any())).thenAnswer(
      (_) async => okQueryResult({
        'getActionGoalsTrend': json.decode(
          r'{ "goal_id": 1, "cadence": "daily", "weeks": 2, "buckets": [] }',
        ),
      }),
    );
    final repo = KgqlGoalRepository(client: mock);
    final t = await repo.getActionGoalsTrend(goalId: 1, weeks: 2);
    expect(t.goalId, 1);
    expect(t.cadence, GoalCadence.daily);
  });
}
