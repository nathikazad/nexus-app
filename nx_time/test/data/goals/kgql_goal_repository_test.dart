import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_time/data/goals/kgql_goal_repository.dart';
import 'package:nx_time/data/goals/goal_attr_keys.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/domain/goals/goal.dart';
import 'package:nx_time/domain/goals/goal_cadence.dart';
import 'package:nx_time/domain/goals/goal_selected_attribute.dart';
import 'package:nx_time/domain/goals/goal_threshold.dart';

import '../../_support/mock_graphql_client.dart';

class _AuthLoggedIn extends AuthController {
  _AuthLoggedIn() : super(initialDelay: Duration.zero, skipBackendPing: true);
  @override
  Future<User?> build() async =>
      User(userId: '1', preset: BackendPreset.localhost);
}

const _week = r'''
{ "week_start": "2026-04-20", "items": [] }
''';

void main() {
  setUpAll(registerGraphqlFallbacks);

  test('getActionGoalsWeek returns empty domain list', () async {
    final mock = MockGraphQLClient();
    when(() => mock.query(any())).thenAnswer(
      (_) async => okQueryResult({'getActionGoalsWeek': json.decode(_week)}),
    );
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_AuthLoggedIn.new),
        graphqlClientProvider.overrideWithValue(mock),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authProvider.future);
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
    final repo = KgqlGoalRepository(
      client: mock,
      loadGoalSchema: () => throw UnimplementedError(),
    );
    final t = await repo.getActionGoalsTrend(goalId: 1, weeks: 2);
    expect(t.goalId, 1);
    expect(t.cadence, GoalCadence.daily);
  });

  test('getById maps getKgqlModels row to Goal', () async {
    final mock = MockGraphQLClient();
    when(() => mock.query(any())).thenAnswer(
      (_) async => okQueryResult({
        'getKgqlModels': [
          {
            'id': 7,
            'name': 'Rest',
            'model_type_id': 1,
            kGoalAttrLabel: 'Rest',
            kGoalAttrActive: true,
            kGoalAttrCadence: 'daily',
            kGoalAttrModelType: 'Sleep',
            kGoalAttrFilter: null,
            kGoalAttrSelectedAttribute: 'end_time',
            kGoalAttrAggregation: 'sum',
            kGoalAttrMetric: 'duration',
            kGoalAttrThresholdOp: '>=',
            kGoalAttrThresholdValue: 8 * 3600,
            kGoalAttrMeta: null,
          },
        ],
      }),
    );
    final repo = KgqlGoalRepository(
      client: mock,
      loadGoalSchema: () async => ModelType(
        id: 1,
        name: 'Goal',
        attributes: [
          AttributeDefinition(key: kGoalAttrLabel, valueType: 'string'),
        ],
      ),
    );
    final g = await repo.getById(7);
    expect(g, isNotNull);
    expect(g!.id, 7);
    expect(g.label, 'Rest');
    expect(g.selectedAttribute, GoalSelectedAttribute.duration);
    expect(g.thresholdValue, closeTo(8.0, 0.001));
    expect(g.actionModelTypeName, 'Sleep');
  });

  test('create sends set_kgql_models and returns new id', () async {
    final mock = MockGraphQLClient();
    when(() => mock.mutate(any())).thenAnswer(
      (_) async => okMutationResult({
        'setKgqlModels': {
          'json': {'id': 55},
        },
      }),
    );
    final repo = KgqlGoalRepository(
      client: mock,
      loadGoalSchema: () => throw UnimplementedError(),
    );
    final id = await repo.create(
      Goal(
        label: 'Gym goal',
        cadence: GoalCadence.daily,
        actionModelTypeName: 'Workout',
        selectedAttribute: GoalSelectedAttribute.count,
        op: GoalThresholdOp.gte,
        thresholdValue: 1,
        preferredDays: const [],
        autoGenerateTasks: false,
      ),
    );
    expect(id, 55);
    final captured =
        verify(() => mock.mutate(captureAny())).captured.single
            as MutationOptions;
    final input = captured.variables['input']! as Map<String, dynamic>;
    final data = input['data'] as Map<String, dynamic>;
    expect(data['name'], 'Gym goal');
    expect(data['model_type'], 'Goal');
    expect(data['id'], isNull);
  });

  test('update sends id and name', () async {
    final mock = MockGraphQLClient();
    when(() => mock.mutate(any())).thenAnswer(
      (_) async => okMutationResult({
        'setKgqlModels': {
          'json': {'id': 2},
        },
      }),
    );
    final repo = KgqlGoalRepository(
      client: mock,
      loadGoalSchema: () => throw UnimplementedError(),
    );
    final id = await repo.update(
      Goal(
        id: 2,
        label: 'Updated',
        cadence: GoalCadence.daily,
        actionModelTypeName: 'Sleep',
        selectedAttribute: GoalSelectedAttribute.duration,
        op: GoalThresholdOp.gte,
        thresholdValue: 7,
        preferredDays: const [],
        autoGenerateTasks: false,
      ),
    );
    expect(id, 2);
    final captured =
        verify(() => mock.mutate(captureAny())).captured.single
            as MutationOptions;
    final input = captured.variables['input']! as Map<String, dynamic>;
    final data = input['data'] as Map<String, dynamic>;
    expect(data['id'], 2);
    expect(data['name'], 'Updated');
  });

  test('delete sends set_kgql_models delete payload', () async {
    final mock = MockGraphQLClient();
    when(() => mock.mutate(any())).thenAnswer(
      (_) async => okMutationResult({
        'setKgqlModels': {
          'json': {'id': 9},
        },
      }),
    );
    final repo = KgqlGoalRepository(
      client: mock,
      loadGoalSchema: () => throw UnimplementedError(),
    );
    await repo.delete(9);
    final captured =
        verify(() => mock.mutate(captureAny())).captured.single
            as MutationOptions;
    final input = captured.variables['input']! as Map<String, dynamic>;
    final data = input['data'] as Map<String, dynamic>;
    expect(data['id'], 9);
    expect(data['delete'], isTrue);
  });
}
