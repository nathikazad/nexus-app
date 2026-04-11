@Tags(['providers'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart' show Tags;
import 'package:nx_db/nx_db.dart';
import 'package:nx_db/src/models/requests/SetModelRequest.dart';

class _MockGql extends Mock implements GraphQLClient {}

QueryResult _ok(Map<String, dynamic>? data) => QueryResult(
      options: QueryOptions(document: gql('query { __typename }')),
      source: QueryResultSource.network,
      data: data,
    );

void main() {
  setUpAll(() {
    registerFallbackValue(QueryOptions(document: gql('query { __typename }')));
    registerFallbackValue(MutationOptions(document: gql('mutation { __typename }')));
  });

  group('PM models_provider', () {
    test('PM7.1 variables contain filter and struct', () async {
      final mock = _MockGql();
      QueryOptions? captured;
      when(() => mock.query(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as QueryOptions;
        return _ok({
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

    test('PM7.2 string JSON response', () async {
      final mock = _MockGql();
      when(() => mock.query(any())).thenAnswer(
        (_) async => _ok({
          'getKgqlModels': '[{"id":1,"name":"S","model_type_id":9}]',
        }),
      );

      final container = ProviderContainer(
        overrides: [graphqlClientProvider.overrideWithValue(mock)],
      );
      addTearDown(container.dispose);

      final list = await container.read(modelsProvider(9).future);
      expect(list.length, 1);
      expect(list.first.name, 'S');
    });

    test('PM7.3 native list response', () async {
      final mock = _MockGql();
      when(() => mock.query(any())).thenAnswer(
        (_) async => _ok({
          'getKgqlModels': [
            {'id': 1, 'name': 'N', 'model_type_id': 9},
          ],
        }),
      );

      final container = ProviderContainer(
        overrides: [graphqlClientProvider.overrideWithValue(mock)],
      );
      addTearDown(container.dispose);

      final list = await container.read(modelsProvider(9).future);
      expect(list.first.name, 'N');
    });

    test('PM7.4 modelProvider filter id eq', () async {
      final mock = _MockGql();
      QueryOptions? captured;
      when(() => mock.query(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as QueryOptions;
        return _ok({
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

    test('PM7.5 createModel wraps input.data', () async {
      final mock = _MockGql();
      MutationOptions? captured;
      when(() => mock.mutate(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as MutationOptions;
        return QueryResult(
          options: MutationOptions(document: gql('mutation { __typename }')),
          source: QueryResultSource.network,
          data: {
            'setKgqlModels': {
              'json': '{"id": 5}',
            },
          },
        );
      });

      final container = ProviderContainer(
        overrides: [graphqlClientProvider.overrideWithValue(mock)],
      );
      addTearDown(container.dispose);

      final id = await createModel(
        container,
        SetModelRequest(modelType: 'Person', name: 'Bob'),
      );

      expect(id, 5);
      final input = captured!.variables['input'] as Map<String, dynamic>;
      final data = input['data'] as Map<String, dynamic>;
      expect(data['model_type'], 'Person');
    });

    test('PM7.6 createModel parses id from string json', () async {
      final mock = _MockGql();
      when(() => mock.mutate(any())).thenAnswer(
        (_) async => QueryResult(
          options: MutationOptions(document: gql('mutation { __typename }')),
          source: QueryResultSource.network,
          data: {
            'setKgqlModels': {'json': '{"id": 99}'},
          },
        ),
      );

      final container = ProviderContainer(
        overrides: [graphqlClientProvider.overrideWithValue(mock)],
      );
      addTearDown(container.dispose);

      final id = await createModel(container, SetModelRequest(name: 'X', modelType: 'Y'));
      expect(id, 99);
    });

    test('PM7.7 mutate exception propagates', () async {
      final mock = _MockGql();
      when(() => mock.mutate(any())).thenAnswer(
        (_) async => QueryResult(
          options: MutationOptions(document: gql('mutation { __typename }')),
          source: QueryResultSource.network,
          exception: OperationException(),
          data: null,
        ),
      );

      final container = ProviderContainer(
        overrides: [graphqlClientProvider.overrideWithValue(mock)],
      );
      addTearDown(container.dispose);

      expect(
        () => createModel(container, SetModelRequest(modelType: 'P', name: 'n')),
        throwsA(isA<OperationException>()),
      );
    });
  });
}
