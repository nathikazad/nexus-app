import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_expense/data/teller/teller_timeline_api.dart';

class _Client extends Mock implements GraphQLClient {}

void main() {
  setUpAll(
    () => registerFallbackValue(
      QueryOptions(document: gql('query { __typename }')),
    ),
  );
  test(
    'transaction detail uses exact id and wall-clock time, with linked models',
    () async {
      final client = _Client();
      QueryOptions? request;
      when(() => client.query(any())).thenAnswer((call) async {
        request = call.positionalArguments.single as QueryOptions;
        return QueryResult(
          options: request!,
          source: QueryResultSource.network,
          data: {
            'allTimelineEvents': {
              'nodes': [
                {
                  'id': '17',
                  'time': '2026-09-15T08:15:20.123456',
                  'source': 'bofa',
                  'eventType': 'transaction',
                  'payload': {'amount': '25'},
                  'modelTimelineEventLinksByEventTimeAndEventId': {
                    'nodes': [
                      {
                        'id': '22',
                        'modelByModelId': {
                          'id': 8,
                          'name': 'Adapters',
                          'modelTypeByModelTypeId': {'name': 'Expense'},
                        },
                      },
                    ],
                  },
                },
              ],
            },
          },
        );
      });
      final row = await fetchTellerTimelineEvent(
        client,
        eventId: '17',
        time: DateTime.parse('2026-09-15T08:15:20.123456'),
      );
      expect(request!.variables, {
        'condition': {'id': '17', 'time': '2026-09-15T08:15:20.123456'},
      });
      expect(request!.fetchPolicy, FetchPolicy.networkOnly);
      expect(row!.linkedModels.single.id, 8);
      expect(row.linkedModels.single.linkId, '22');
    },
  );
  test(
    'absent transaction produces not-found instead of another row',
    () async {
      final client = _Client();
      when(() => client.query(any())).thenAnswer(
        (call) async => QueryResult(
          options: call.positionalArguments.single as QueryOptions,
          source: QueryResultSource.network,
          data: {
            'allTimelineEvents': {'nodes': []},
          },
        ),
      );
      expect(
        await fetchTellerTimelineEvent(
          client,
          eventId: '99',
          time: DateTime(2026, 9, 15),
        ),
        isNull,
      );
    },
  );
}
