@Tags(['providers'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart' show Tags;
import 'package:nx_db/nx_db.dart';

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

  group('PT model_types_provider', () {
    test('PT8.1 empty model_types returns roots', () async {
      final mock = _MockGql();
      when(() => mock.query(any())).thenAnswer(
        (_) async => _ok({
          'getKgqlModelType': [
            {'id': 1, 'name': 'A', 'type_kind': 'abstract'},
            {'id': 2, 'name': 'B', 'type_kind': 'abstract'},
          ],
        }),
      );

      final container = ProviderContainer(
        overrides: [graphqlClientProvider.overrideWithValue(mock)],
      );
      addTearDown(container.dispose);

      final roots = await container.read(modelTypesProvider.future);
      expect(roots.length, 2);
      expect(roots.map((e) => e.name).toList(), ['A', 'B']);
    });

    test('PT8.2 recursive parse children', () async {
      final mock = _MockGql();
      when(() => mock.query(any())).thenAnswer(
        (_) async => _ok({
          'getKgqlModelType': [
            {
              'id': 1,
              'name': 'Root',
              'type_kind': 'abstract',
              'children': [
                {'id': 10, 'name': 'Child'},
              ],
            },
          ],
        }),
      );

      final container = ProviderContainer(
        overrides: [graphqlClientProvider.overrideWithValue(mock)],
      );
      addTearDown(container.dispose);

      final roots = await container.read(modelTypesProvider.future);
      expect(roots.first.children?.length, 1);
      expect(roots.first.children!.first.parentId, 1);
    });

    test('PT8.3 modelTypeProvider includes tag_systems', () async {
      final mock = _MockGql();
      when(() => mock.query(any())).thenAnswer(
        (_) async => _ok({
          'getKgqlModelType': [
            {
              'id': 9,
              'name': 'Expense',
              'tag_systems': [
                {
                  'id': 1,
                  'name': 'Cat',
                  'is_hierarchical': false,
                  'selection_mode': 'multiple',
                  'nodes': [],
                },
              ],
            },
          ],
        }),
      );

      final container = ProviderContainer(
        overrides: [graphqlClientProvider.overrideWithValue(mock)],
      );
      addTearDown(container.dispose);

      final mt = await container.read(modelTypeProvider(9).future);
      expect(mt, isNotNull);
      expect(mt!.tagSystems?.length, 1);
      expect(mt.tagSystems!.first.name, 'Cat');
    });

    test('PT8.4 createModelType parses id', () async {
      final mock = _MockGql();
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

    test('PT8.5 updateModelType requires id', () async {
      final mock = _MockGql();
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
  });
}
