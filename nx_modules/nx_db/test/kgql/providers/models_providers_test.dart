@Tags(['provider'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_db/riverpod.dart';

import '../../_support/mock_graphql_client.dart';

class _AuthLoggedIn extends AuthController {
  _AuthLoggedIn() : super(initialDelay: Duration.zero, skipBackendPing: true);
  @override
  Future<User?> build() async => User(
        userId: '1',
        preset: BackendPreset.localhost,
      );
}

void main() {
  setUpAll(registerGraphqlFallbacks);

  group('models_providers', () {
    test('PM7.1 modelsProvider variables contain filter and struct', () async {
      final mock = MockGraphQLClient();
      QueryOptions? captured;
      when(() => mock.query(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as QueryOptions;
        return okQueryResult({
          'getKgqlModels': [
            {'id': 1, 'name': 'A', 'model_type_id': 9},
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

      await container.read(modelsProvider(9).future);

      expect(captured, isNotNull);
      expect(captured!.variables['filter'], containsPair('model_type', 9));
      expect(captured!.variables['struct'], isNotNull);
      expect(captured!.variables.containsKey('domainId'), isFalse);
    });

    test('modelsProvider filters list to matching modelTypeId', () async {
      final mock = MockGraphQLClient();
      when(() => mock.query(any())).thenAnswer(
        (_) async => okQueryResult({
          'getKgqlModels': [
            {'id': 1, 'name': 'A', 'model_type_id': 9},
            {'id': 2, 'name': 'B', 'model_type_id': 8},
          ],
        }),
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_AuthLoggedIn.new),
          graphqlClientProvider.overrideWithValue(mock),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authProvider.future);

      final list = await container.read(modelsProvider(9).future);
      expect(list.length, 1);
      expect(list.first.name, 'A');
    });

    test('modelListProvider preserves descendant model types', () async {
      final mock = MockGraphQLClient();
      QueryOptions? captured;
      when(() => mock.query(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as QueryOptions;
        return okQueryResult({
          'getKgqlModels': [
            {
              'id': 1,
              'name': 'Run',
              'model_type_id': 10,
              'model_type': {'id': 10, 'name': 'Run'},
            },
            {
              'id': 2,
              'name': 'Yoga',
              'model_type_id': 11,
              'model_type': {'id': 11, 'name': 'Yoga'},
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

      final list = await container.read(
        modelListProvider(const ModelListQuery(modelTypeId: 9)).future,
      );

      expect(captured, isNotNull);
      expect(captured!.variables['filter'], containsPair('model_type', 9));
      expect(list.map((model) => model.modelTypeId), [10, 11]);
      expect(list.last.modelType?.name, 'Yoga');
    });

    test('PM7.4 modelProvider filter id eq', () async {
      final mock = MockGraphQLClient();
      QueryOptions? captured;
      when(() => mock.query(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as QueryOptions;
        return okQueryResult({
          'getKgqlModels': [
            {'id': 42, 'name': 'X', 'model_type_id': 1},
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

      await container.read(modelProvider(42).future);

      final filters = (captured!.variables['filter'] as Map)['filters'] as List;
      expect(filters.first['key'], 'id');
      expect(filters.first['op'], '=');
      expect(filters.first['value'], '42');
    });

    test('createModel delegates to setKgqlModel', () async {
      final mock = MockGraphQLClient();
      when(() => mock.mutate(any())).thenAnswer(
        (_) async => QueryResult(
          options: MutationOptions(document: gql('mutation { __typename }')),
          source: QueryResultSource.network,
          data: {
            'setKgqlModels': {'json': '{"id": 5}'},
          },
        ),
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_AuthLoggedIn.new),
          graphqlClientProvider.overrideWithValue(mock),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authProvider.future);

      final id = await createModel(
        container,
        SetModelRequest(modelType: 'Person', name: 'Bob'),
      );
      expect(id, 5);
    });
  });
}
