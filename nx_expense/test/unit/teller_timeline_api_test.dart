import 'package:flutter_test/flutter_test.dart';
import 'package:nx_expense/data/teller/teller_timeline_api.dart';

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
