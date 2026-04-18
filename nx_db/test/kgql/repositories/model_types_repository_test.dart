@Tags(['repository'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/nx_db.dart';
import 'package:test/test.dart' show Tags;

import '../../_support/mock_graphql_client.dart';

void main() {
  setUpAll(registerGraphqlFallbacks);

  group('fetchAllModelTypes', () {
    test('parses roots', () async {
      final mock = MockGraphQLClient();
      when(() => mock.query(any())).thenAnswer(
        (_) async => okQueryResult({
          'getKgqlModelType': [
            {'id': 1, 'name': 'A', 'type_kind': 'abstract'},
            {'id': 2, 'name': 'B', 'type_kind': 'abstract'},
          ],
        }),
      );

      final roots = await fetchAllModelTypes(mock);
      expect(roots.length, 2);
      expect(roots.map((e) => e.name).toList(), ['A', 'B']);
    });

    test('recursive parse children', () async {
      final mock = MockGraphQLClient();
      when(() => mock.query(any())).thenAnswer(
        (_) async => okQueryResult({
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

      final roots = await fetchAllModelTypes(mock);
      expect(roots.first.children?.length, 1);
      expect(roots.first.children!.first.parentId, 1);
    });

    test('string JSON response', () async {
      final mock = MockGraphQLClient();
      when(() => mock.query(any())).thenAnswer(
        (_) async => okQueryResult({
          'getKgqlModelType': '[{"id":1,"name":"S","type_kind":"base"}]',
        }),
      );

      final roots = await fetchAllModelTypes(mock);
      expect(roots.length, 1);
      expect(roots.first.name, 'S');
    });
  });

  group('fetchKgqlModelTypeById', () {
    test('includes tag_systems when present', () async {
      final mock = MockGraphQLClient();
      when(() => mock.query(any())).thenAnswer(
        (_) async => okQueryResult({
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

      final mt = await fetchKgqlModelTypeById(mock, 9);
      expect(mt, isNotNull);
      expect(mt!.tagSystems?.length, 1);
      expect(mt.tagSystems!.first.name, 'Cat');
    });
  });

  group('setKgqlModelType', () {
    test('parses id from string json', () async {
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

      final id = await setKgqlModelType(
        mock,
        SetModelTypeRequest(name: 'NewType', typeKind: 'base'),
      );
      expect(id, 42);
    });
  });
}
