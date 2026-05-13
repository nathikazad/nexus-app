@Tags(['repository'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/kgql.dart';
import 'package:test/test.dart' show Tags;

import '../../_support/mock_graphql_client.dart';

void main() {
  setUpAll(registerGraphqlFallbacks);

  group('parseKgqlAggregateResult', () {
    test('A8.1 parses string JSON result', () {
      final out = parseKgqlAggregateResult('{"aggregated_value": 1457}');
      expect(out['aggregated_value'], 1457);
    });

    test('parses map result', () {
      final out =
          parseKgqlAggregateResult(<String, dynamic>{'aggregated_value': 3});
      expect(out['aggregated_value'], 3);
    });

    test('null yields empty map', () {
      expect(parseKgqlAggregateResult(null), {});
    });

    test('A8.2 grouped JSON string as array', () {
      final out = parseKgqlAggregateResult(
        '[{"bucket":"a","aggregated_value":10},{"bucket":"b","aggregated_value":20}]',
      );
      expect(out['grouped'], isA<List>());
      expect((out['grouped'] as List).length, 2);
    });

    test('A8.2 raw list', () {
      final out = parseKgqlAggregateResult([
        {'k': 1},
      ]);
      expect(out['grouped'], isA<List>());
    });
  });

  group('getKgqlAggregate', () {
    test('A8.1 happy path via client', () async {
      final client = MockGraphQLClient();
      when(() => client.query(any())).thenAnswer(
        (_) async => QueryResult(
          options: QueryOptions(document: gql('query { __typename }')),
          source: QueryResultSource.network,
          data: {
            'getKgqlAggregate': '{"aggregated_value": 1457}',
          },
        ),
      );

      final out = await getKgqlAggregate(
        client,
        {'model_type': 'Expense'},
        {'metric': 'sum', 'key': 'cost', 'group': null},
      );
      expect(out['aggregated_value'], 1457);
      final captured = verify(() => client.query(captureAny())).captured.single
          as QueryOptions;
      expect(
        captured.variables.keys,
        containsAll(['filterkgql', 'aggregate']),
      );
      expect(captured.variables.containsKey('domainId'), isFalse);
      expect(captured.variables['filterkgql'], {'model_type': 'Expense'});
      expect(
        captured.variables['aggregate'],
        {'metric': 'sum', 'key': 'cost', 'group': null},
      );
    });

    test('A8.3 GraphQL error propagates', () async {
      final client = MockGraphQLClient();
      when(() => client.query(any())).thenAnswer(
        (_) async => QueryResult(
          options: QueryOptions(document: gql('query { __typename }')),
          source: QueryResultSource.network,
          exception: OperationException(),
          data: null,
        ),
      );

      expect(
        () => getKgqlAggregate(
          client,
          {'model_type': 'Expense'},
          {'metric': 'count', 'key': null, 'group': null},
        ),
        throwsA(isA<OperationException>()),
      );
    });
  });
}
