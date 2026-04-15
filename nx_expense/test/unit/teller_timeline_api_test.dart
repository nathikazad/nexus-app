import 'package:flutter_test/flutter_test.dart';
import 'package:nx_expense/data/teller_timeline_api.dart';

void main() {
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
      final p = {
        'description': 'Line one\nLine two',
      };
      expect(tellerTransactionTitleLine(p), 'Line one');
    });

    test('default when empty', () {
      expect(tellerTransactionTitleLine({}), 'Teller transaction');
    });
  });
}
