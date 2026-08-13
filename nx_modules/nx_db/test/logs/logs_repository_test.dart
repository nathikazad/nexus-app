import 'package:flutter_test/flutter_test.dart';
import 'package:gql/language.dart' show printNode;
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/nx_db.dart';

import '../_support/mock_graphql_client.dart';

void main() {
  setUpAll(registerGraphqlFallbacks);

  test('fetchLogById returns exact PostGraphile timestamp and payload',
      () async {
    final mock = MockGraphQLClient();
    QueryOptions? captured;
    when(() => mock.query(any())).thenAnswer((invocation) async {
      captured = invocation.positionalArguments.single as QueryOptions;
      return QueryResult(
        options: QueryOptions(document: gql('query { __typename }')),
        source: QueryResultSource.network,
        data: const {
          'allLogs': {
            'nodes': [
              {
                'time': '2026-07-03T22:55:58.973779+00:00',
                'id': '23291',
                'payload': {
                  'seq': 4,
                  'agent_run_id': 'run-1',
                },
              },
            ],
          },
        },
      );
    });

    final row = await fetchLogById(mock, id: '23291');

    verify(() => mock.query(any())).called(1);
    expect(captured!.variables['id'], '23291');
    expect(printNode(captured!.document), contains('allLogs'));
    expect(row?.id, '23291');
    expect(row?.time?.toUtc().toIso8601String(), '2026-07-03T22:55:58.973779Z');
    expect(row?.payload['agent_run_id'], 'run-1');
  });

  test('updateLogPayload sends target row and replacement payload', () async {
    final mock = MockGraphQLClient();
    MutationOptions? captured;
    when(() => mock.mutate(any())).thenAnswer((invocation) async {
      captured = invocation.positionalArguments.single as MutationOptions;
      return QueryResult(
        options: MutationOptions(document: gql('mutation { __typename }')),
        source: QueryResultSource.network,
        data: const {
          'updateLogByTimeAndId': {
            'log': {
              'time': '2026-07-03T12:00:02Z',
              'id': '42',
              'payload': {'existing': true},
            },
          },
        },
      );
    });

    final payload = {
      'existing': true,
      'correction': {
        'note': 'bad change',
        'incorrect': true,
        'resolved': false,
      },
    };
    await updateLogPayload(
      mock,
      time: DateTime.parse('2026-07-03T12:00:02Z'),
      id: '42',
      payload: payload,
    );

    verify(() => mock.mutate(any())).called(1);
    expect(captured!.variables['time'], '2026-07-03T12:00:02.000Z');
    expect(captured!.variables['id'], '42');
    expect(captured!.variables['payload'], payload);
    expect(
      printNode(captured!.document),
      contains('updateLogByTimeAndId'),
    );
  });

  test('updateLogPayload throws GraphQL exception', () async {
    final mock = MockGraphQLClient();
    when(() => mock.mutate(any())).thenAnswer(
      (_) async => QueryResult(
        options: MutationOptions(document: gql('mutation { __typename }')),
        exception: OperationException(),
        source: QueryResultSource.network,
      ),
    );

    expect(
      () => updateLogPayload(
        mock,
        time: DateTime.parse('2026-07-03T12:00:02Z'),
        id: '42',
        payload: const {'existing': true},
      ),
      throwsA(isA<OperationException>()),
    );
  });
}
