@Tags(['provider', 'providers'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/nx_db.dart';
import 'package:test/test.dart' show Tags;

import '../../_support/mock_graphql_client.dart';

void main() {
  setUpAll(registerGraphqlFallbacks);

  group('model_types_providers', () {
    test('modelTypesProvider uses fetchAllModelTypes', () async {
      final mock = MockGraphQLClient();
      when(() => mock.query(any())).thenAnswer(
        (_) async => okQueryResult({
          'getKgqlModelType': [
            {'id': 1, 'name': 'A', 'type_kind': 'abstract'},
          ],
        }),
      );

      final container = ProviderContainer(
        overrides: [graphqlClientProvider.overrideWithValue(mock)],
      );
      addTearDown(container.dispose);

      final roots = await container.read(modelTypesProvider.future);
      expect(roots.length, 1);
      expect(roots.first.name, 'A');
    });

    test('PT8.5 updateModelType requires id', () async {
      final mock = MockGraphQLClient();
      final container = ProviderContainer(
        overrides: [graphqlClientProvider.overrideWithValue(mock)],
      );
      addTearDown(container.dispose);

      expect(
        () => updateModelType(
          container,
          SetModelTypeRequest(name: 'X', typeKind: 'base'),
        ),
        throwsA(isA<Exception>().having((e) => e.toString(), 'msg', contains('id is required'))),
      );
    });

    test('createModelType delegates to setKgqlModelType', () async {
      final mock = MockGraphQLClient();
      when(() => mock.mutate(any())).thenAnswer(
        (_) async => QueryResult(
          options: MutationOptions(document: gql('mutation { __typename }')),
          source: QueryResultSource.network,
          data: {
            'setKgqlModelTypes': {'json': '{"id": 42}'},
          },
        ),
      );

      final container = ProviderContainer(
        overrides: [graphqlClientProvider.overrideWithValue(mock)],
      );
      addTearDown(container.dispose);

      final id = await createModelType(
        container,
        SetModelTypeRequest(name: 'NewType', typeKind: 'base'),
      );
      expect(id, 42);
    });
  });
}
