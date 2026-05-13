import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_time/data/action/action_attr_keys.dart';
import 'package:nx_time/data/action/kgql_action_repository.dart';
import 'package:nx_time/data/providers.dart';

import '../../_support/mock_graphql_client.dart';

class _AuthLoggedIn extends AuthController {
  _AuthLoggedIn() : super(initialDelay: Duration.zero, skipBackendPing: true);
  @override
  Future<User?> build() async =>
      User(userId: '1', preset: BackendPreset.localhost);
}

void main() {
  setUpAll(registerGraphqlFallbacks);

  test('linkChildAction sends set_kgql_models with Action link', () async {
    final mock = MockGraphQLClient();
    when(() => mock.mutate(any())).thenAnswer(
      (_) async => okMutationResult({
        'setKgqlModels': {
          'json': {'id': 99},
        },
      }),
    );

    final repo = KgqlActionRepository(
      client: mock,
      loadActionSchema: () async => throw UnsupportedError('not used'),
    );

    final id = await repo.linkChildAction(parentId: 10, childId: 20);
    expect(id, 99);

    final captured =
        verify(() => mock.mutate(captureAny())).captured.single
            as MutationOptions;
    final input = captured.variables!['input'] as Map<String, dynamic>;
    final data = input['data'] as Map<String, dynamic>;
    expect(data['id'], 10);
    final rels = data['relations'] as List<dynamic>;
    expect(rels.length, 1);
    expect(rels.single['model_type'], kActionRelationKey);
    expect(rels.single['link'], [20]);
  });

  test('unlinkChildAction sends relation delete by id', () async {
    final mock = MockGraphQLClient();
    when(() => mock.mutate(any())).thenAnswer(
      (_) async => okMutationResult({
        'setKgqlModels': {
          'json': {'id': 10},
        },
      }),
    );

    final repo = KgqlActionRepository(
      client: mock,
      loadActionSchema: () async => throw UnsupportedError('not used'),
    );

    await repo.unlinkChildAction(parentId: 10, relationId: 777);

    final captured =
        verify(() => mock.mutate(captureAny())).captured.single
            as MutationOptions;
    final input = captured.variables!['input'] as Map<String, dynamic>;
    final data = input['data'] as Map<String, dynamic>;
    expect(data['id'], 10);
    final rels = data['relations'] as List<dynamic>;
    expect(rels.single['id'], 777);
    expect(rels.single['delete'], isTrue);
  });

  test('listForCalendarDay loads schema then models', () async {
    final mock = MockGraphQLClient();
    var queryCount = 0;
    when(() => mock.query(any())).thenAnswer((_) async {
      queryCount++;
      if (queryCount == 1) {
        return okQueryResult({
          'getKgqlModelType': [
            {
              'id': 1,
              'name': 'Action',
              'attributes': [
                {'key': 'start_time', 'value_type': 'datetime'},
                {'key': 'end_time', 'value_type': 'datetime'},
              ],
            },
          ],
        });
      }
      return okQueryResult({
        'getKgqlModels': [
          {
            'id': 7,
            'name': 'Morning Run',
            'model_type_id': 3,
            'start_time': '2026-04-18T08:00:00.000',
            'end_time': '2026-04-18T09:00:00.000',
            'model_type': {'id': 3, 'name': 'Workout', 'type_kind': 'base'},
          },
        ],
      });
    });

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_AuthLoggedIn.new),
        graphqlClientProvider.overrideWithValue(mock),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authProvider.future);

    final repo = container.read(actionRepositoryProvider);
    final list = await repo.listForCalendarDay(DateTime(2026, 4, 18));
    expect(list.length, 1);
    expect(list.first.name, 'Morning Run');
    expect(queryCount, 2);
  });
}
