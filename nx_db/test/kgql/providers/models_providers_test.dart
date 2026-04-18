@Tags(['provider'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_db/riverpod.dart';
import 'package:test/test.dart' show Tags;

import '../../_support/mock_graphql_client.dart';

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
        overrides: [graphqlClientProvider.overrideWithValue(mock)],
      );
      addTearDown(container.dispose);

      await container.read(modelsProvider(9).future);

      expect(captured, isNotNull);
      expect(captured!.variables['filter'], containsPair('model_type', 9));
      expect(captured!.variables['struct'], isNotNull);
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
        overrides: [graphqlClientProvider.overrideWithValue(mock)],
      );
      addTearDown(container.dispose);

      final list = await container.read(modelsProvider(9).future);
      expect(list.length, 1);
      expect(list.first.name, 'A');
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
        overrides: [graphqlClientProvider.overrideWithValue(mock)],
      );
      addTearDown(container.dispose);

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
        overrides: [graphqlClientProvider.overrideWithValue(mock)],
      );
      addTearDown(container.dispose);

      final id = await createModel(
        container,
        SetModelRequest(modelType: 'Person', name: 'Bob'),
      );
      expect(id, 5);
    });
  });
}
