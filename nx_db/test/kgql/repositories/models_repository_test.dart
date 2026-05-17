@Tags(['repository'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/kgql.dart';

import '../../_support/mock_graphql_client.dart';

void main() {
  setUpAll(registerGraphqlFallbacks);

  group('parseKgqlModelsResult', () {
    test('null → empty list', () {
      expect(parseKgqlModelsResult(null), isEmpty);
    });

    test('native list of maps', () {
      final list = parseKgqlModelsResult([
        {'id': 1, 'name': 'A', 'model_type_id': 9},
      ]);
      expect(list.length, 1);
      expect(list.first.id, 1);
      expect(list.first.name, 'A');
    });

    test('JSON string list', () {
      final list = parseKgqlModelsResult(
        '[{"id":2,"name":"B","model_type_id":9}]',
      );
      expect(list.length, 1);
      expect(list.first.name, 'B');
    });

    test('skips non-map entries', () {
      final list = parseKgqlModelsResult([
        {'id': 1, 'name': 'Ok', 'model_type_id': 9},
        'bad',
        3,
      ]);
      expect(list.length, 1);
      expect(list.first.name, 'Ok');
    });
  });

  group('fetchKgqlModels', () {
    test('passes filter and struct', () async {
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

      await fetchKgqlModels(
        mock,
        filter: {'model_type': 'Expense'},
        struct: const {'id': true},
      );

      expect(captured, isNotNull);
      expect(captured!.variables['filter'], {'model_type': 'Expense'});
      expect(captured!.variables['struct'], {'id': true});
      expect(captured!.variables.containsKey('domainId'), isFalse);
    });
  });

  group('fetchKgqlModelById', () {
    test('builds id filter and returns first model', () async {
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

      final m = await fetchKgqlModelById(
        mock,
        modelTypeName: 'Person',
        id: 42,
        struct: const {'id': true},
      );

      expect(m, isNotNull);
      expect(m!.name, 'X');
      final filter = captured!.variables['filter'] as Map<String, dynamic>;
      expect(filter['model_type'], 'Person');
      final filters = filter['filters'] as List<dynamic>;
      expect(filters.first['key'], 'id');
      expect(filters.first['op'], '=');
      expect(filters.first['value'], '42');
    });
  });

  group('setKgqlModel', () {
    test('create wraps input.data and parses id', () async {
      final mock = MockGraphQLClient();
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

      final id = await setKgqlModel(
        mock,
        SetModelRequest(modelType: 'Person', name: 'Bob'),
      );

      expect(id, 5);
      final input = captured!.variables['input'] as Map<String, dynamic>;
      final data = input['data'] as Map<String, dynamic>;
      expect(data['model_type'], 'Person');
      expect(input.containsKey('domainId'), isFalse);
    });

    test('parses id from map json field', () async {
      final mock = MockGraphQLClient();
      when(() => mock.mutate(any())).thenAnswer(
        (_) async => QueryResult(
          options: MutationOptions(document: gql('mutation { __typename }')),
          source: QueryResultSource.network,
          data: {
            'setKgqlModels': {
              'json': <String, dynamic>{'id': 101},
            },
          },
        ),
      );

      final id = await setKgqlModel(
        mock,
        SetModelRequest(name: 'X', modelType: 'Y'),
      );
      expect(id, 101);
    });

    test('delete uses delete flag in payload', () async {
      final mock = MockGraphQLClient();
      MutationOptions? captured;
      when(() => mock.mutate(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as MutationOptions;
        return QueryResult(
          options: MutationOptions(document: gql('mutation { __typename }')),
          source: QueryResultSource.network,
          data: {
            'setKgqlModels': {'json': '{"id": 3}'},
          },
        );
      });

      final id = await setKgqlModel(
        mock,
        SetModelRequest(id: 7, delete: true),
      );

      expect(id, 3);
      final data = (captured!.variables['input']
          as Map<String, dynamic>)['data'] as Map<String, dynamic>;
      expect(data['delete'], true);
      expect(data['id'], 7);
    });

    test('mutate exception propagates', () async {
      final mock = MockGraphQLClient();
      final exception = OperationException(
        graphqlErrors: [
          const GraphQLError(
            message: 'name cannot be empty',
            extensions: {'code': 'BAD_USER_INPUT'},
          ),
        ],
      );
      when(() => mock.mutate(any())).thenAnswer(
        (_) async => QueryResult(
          options: MutationOptions(document: gql('mutation { __typename }')),
          source: QueryResultSource.network,
          exception: exception,
          data: null,
        ),
      );

      final logs = <String>[];
      await expectLater(
        runZoned(
          () => setKgqlModel(mock, SetModelRequest(modelType: 'P', name: 'n')),
          zoneSpecification: ZoneSpecification(
            print: (_, __, ___, line) => logs.add(line),
          ),
        ),
        throwsA(isA<OperationException>()),
      );
      expect(logs.join('\n'), contains('KGQL mutation error: setKgqlModels'));
      expect(logs.join('\n'), contains('mutation SetKgqlModels'));
      expect(logs.join('\n'), contains('"model_type": "P"'));
      expect(logs.join('\n'), contains('name cannot be empty'));
    });

    test('missing id in non-delete response throws', () async {
      final mock = MockGraphQLClient();
      when(() => mock.mutate(any())).thenAnswer(
        (_) async => QueryResult(
          options: MutationOptions(document: gql('mutation { __typename }')),
          source: QueryResultSource.network,
          data: {
            'setKgqlModels': {'json': '{}'},
          },
        ),
      );

      expect(
        () => setKgqlModel(mock, SetModelRequest(modelType: 'P', name: 'n')),
        throwsA(isA<Exception>()
            .having((e) => e.toString(), 'msg', contains('No ID returned'))),
      );
    });
  });
}
