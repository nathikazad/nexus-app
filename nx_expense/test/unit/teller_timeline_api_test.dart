import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_expense/data/teller/teller_timeline_api.dart';

class _MockGraphQLClient extends Mock implements GraphQLClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(QueryOptions(document: gql('query { __typename }')));
  });

  group('parseTellerTimelineResponse', () {
    test('empty when no nodes', () {
      expect(parseTellerTimelineResponse(null), isEmpty);
      expect(parseTellerTimelineResponse(<String, dynamic>{}), isEmpty);
      expect(
        parseTellerTimelineResponse({
          'allTimelineEvents': {'nodes': <dynamic>[]},
        }),
        isEmpty,
      );
    });

    test('parses row with linked model', () {
      final data = {
        'allTimelineEvents': {
          'nodes': [
            {
              'time': '2026-03-10T08:00:00.000Z',
              'id': 'te-1',
              'payload': {'amount': '20', 'description': 'Wire'},
              'modelTimelineEventLinksByEventTimeAndEventId': {
                'nodes': [
                  {
                    'id': 'link-1',
                    'modelByModelId': {
                      'id': 7,
                      'name': 'Expense A',
                      'modelTypeByModelTypeId': {'name': 'Expense'},
                    },
                  },
                ],
              },
            },
          ],
        },
      };
      final rows = parseTellerTimelineResponse(data);
      expect(rows.length, 1);
      final r = rows.first;
      expect(r.eventId, 'te-1');
      expect(r.payload['amount'], '20');
      expect(r.linkedModels.length, 1);
      expect(r.linkedModels.first.id, 7);
      expect(r.linkedModels.first.name, 'Expense A');
      expect(r.linkedModels.first.modelTypeName, 'Expense');
      expect(r.linkedModels.first.linkId, 'link-1');
    });

    test('parses range query rows with linked models', () {
      final data = {
        'tellerTimelineEventsForRange': [
          {
            'time': '2026-05-16T00:00:00.000',
            'id': '16845',
            'payload': {'amount': '-13.45', 'description': 'Coffee'},
            'linkedModels': [
              {
                'id': 'link-1',
                'modelByModelId': {
                  'id': 3295,
                  'name': 'Coffee',
                  'modelTypeByModelTypeId': {'name': 'Expense'},
                },
              },
            ],
          },
        ],
      };

      final rows = parseTellerTimelineResponse(data);

      expect(rows.length, 1);
      expect(rows.first.eventId, '16845');
      expect(rows.first.time.year, 2026);
      expect(rows.first.time.month, 5);
      expect(rows.first.time.day, 16);
      expect(rows.first.linkedModels.single.id, 3295);
      expect(rows.first.linkedModels.single.modelTypeName, 'Expense');
    });

    test('fetches only the selected local date range', () async {
      final mock = _MockGraphQLClient();
      when(() => mock.query(any())).thenAnswer(
        (_) async => QueryResult(
          options: QueryOptions(document: gql('query { __typename }')),
          source: QueryResultSource.network,
          data: const {'tellerTimelineEventsForRange': <dynamic>[]},
        ),
      );

      await fetchTellerTimelineEvents(
        mock,
        rangeStart: DateTime(2026, 5),
        rangeEnd: DateTime(2026, 5, 31),
      );

      final captured =
          verify(() => mock.query(captureAny())).captured.single
              as QueryOptions;
      expect(captured.variables['start'], '2026-05-01T00:00:00');
      expect(captured.variables['end'], '2026-06-01T00:00:00');
      expect(captured.variables['first'], 5000);
      expect(
        tellerTimelineEventsQuery,
        contains('tellerTimelineEventsForRange'),
      );
    });

    test('skips invalid time', () {
      final data = {
        'allTimelineEvents': {
          'nodes': [
            {'time': 'bad', 'id': 'x', 'payload': {}},
          ],
        },
      };
      expect(parseTellerTimelineResponse(data), isEmpty);
    });
  });

  group('tellerTransactionTitleLine', () {
    test('prefers counterparty name', () {
      final p = {
        'details': {
          'counterparty': {'name': '  Acme Bank  '},
        },
        'description': 'ignored',
      };
      expect(tellerTransactionTitleLine(p), 'Acme Bank');
    });

    test('falls back to first line of description', () {
      final p = {'description': 'Line one\nLine two'};
      expect(tellerTransactionTitleLine(p), 'Line one');
    });

    test('default when empty', () {
      expect(tellerTransactionTitleLine({}), 'Teller transaction');
    });
  });

  group('tellerRowHasExpenseOrTransferLink', () {
    TellerTransactionRow rowWithLinks(List<LinkedTellerModel> models) {
      return TellerTransactionRow(
        time: DateTime.utc(2026, 3, 10, 8),
        eventId: 'te-x',
        payload: const {},
        linkedModels: models,
      );
    }

    test('false when no linked models', () {
      expect(tellerRowHasExpenseOrTransferLink(rowWithLinks([])), isFalse);
    });

    test('false when only non-expense non-transfer types', () {
      expect(
        tellerRowHasExpenseOrTransferLink(
          rowWithLinks([
            const LinkedTellerModel(
              id: 1,
              name: 'Co',
              modelTypeName: 'Company',
            ),
          ]),
        ),
        isFalse,
      );
    });

    test('true when linked Expense', () {
      expect(
        tellerRowHasExpenseOrTransferLink(
          rowWithLinks([
            const LinkedTellerModel(id: 2, name: 'E', modelTypeName: 'Expense'),
          ]),
        ),
        isTrue,
      );
    });

    test('true when linked Transfer', () {
      expect(
        tellerRowHasExpenseOrTransferLink(
          rowWithLinks([
            const LinkedTellerModel(
              id: 3,
              name: 'T',
              modelTypeName: 'Transfer',
            ),
          ]),
        ),
        isTrue,
      );
    });

    test('true when both Expense and Transfer present', () {
      expect(
        tellerRowHasExpenseOrTransferLink(
          rowWithLinks([
            const LinkedTellerModel(id: 2, name: 'E', modelTypeName: 'Expense'),
            const LinkedTellerModel(
              id: 3,
              name: 'T',
              modelTypeName: 'Transfer',
            ),
          ]),
        ),
        isTrue,
      );
    });
  });

  group('tellerPayloadIsDeleted', () {
    test('false when absent or false', () {
      expect(tellerPayloadIsDeleted({}), isFalse);
      expect(tellerPayloadIsDeleted({'deleted': false}), isFalse);
      expect(tellerPayloadIsDeleted({'deleted': 'false'}), isFalse);
    });

    test('true when bool, string, or non-zero num', () {
      expect(tellerPayloadIsDeleted({'deleted': true}), isTrue);
      expect(tellerPayloadIsDeleted({'deleted': 'true'}), isTrue);
      expect(tellerPayloadIsDeleted({'deleted': '1'}), isTrue);
      expect(tellerPayloadIsDeleted({'deleted': 1}), isTrue);
    });
  });
}
