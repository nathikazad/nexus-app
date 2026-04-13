import 'package:flutter_test/flutter_test.dart';
import 'package:nx_expense/data/expense_timeline_api.dart';

void main() {
  group('parseExpenseTimelineLinks', () {
    test('empty when modelById null', () {
      expect(parseExpenseTimelineLinks(null), isEmpty);
      expect(parseExpenseTimelineLinks(<String, dynamic>{}), isEmpty);
      expect(parseExpenseTimelineLinks({'modelById': null}), isEmpty);
    });

    test('empty nodes', () {
      final data = {
        'modelById': {
          'id': 1,
          'modelTimelineEventLinksByModelId': {'nodes': <dynamic>[]},
        },
      };
      expect(parseExpenseTimelineLinks(data), isEmpty);
    });

    test('parses one link and coerces payload map', () {
      final data = {
        'modelById': {
          'id': 99,
          'modelTimelineEventLinksByModelId': {
            'nodes': [
              {
                'id': 42,
                'timelineEventByEventTimeAndEventId': {
                  'time': '2026-03-15T14:30:00.000Z',
                  'id': 'evt-abc',
                  'payload': {'amount': '10', 'description': 'Coffee'},
                },
              },
            ],
          },
        },
      };
      final links = parseExpenseTimelineLinks(data);
      expect(links.length, 1);
      final l = links.first;
      expect(l.linkId, '42');
      expect(l.eventId, 'evt-abc');
      expect(l.payload['amount'], '10');
      expect(l.payload['description'], 'Coffee');
      expect(l.eventTime.toUtc().year, 2026);
    });

    test('skips node without timeline event or time', () {
      final data = {
        'modelById': {
          'modelTimelineEventLinksByModelId': {
            'nodes': [
              {'id': 1, 'timelineEventByEventTimeAndEventId': null},
              {
                'id': 2,
                'timelineEventByEventTimeAndEventId': {
                  'time': 'invalid',
                  'id': 'x',
                  'payload': {},
                },
              },
            ],
          },
        },
      };
      expect(parseExpenseTimelineLinks(data), isEmpty);
    });

    test('non-Map payload becomes empty map', () {
      final data = {
        'modelById': {
          'modelTimelineEventLinksByModelId': {
            'nodes': [
              {
                'id': 1,
                'timelineEventByEventTimeAndEventId': {
                  'time': '2026-01-01T00:00:00.000Z',
                  'id': 'e1',
                  'payload': 'not-a-map',
                },
              },
            ],
          },
        },
      };
      final l = parseExpenseTimelineLinks(data).single;
      expect(l.payload, isEmpty);
    });
  });

  group('ExpenseTellerLink.toTellerTransactionRow', () {
    test('maps fields; linkedModels empty', () {
      final t = DateTime.utc(2026, 4, 1, 12);
      final link = ExpenseTellerLink(
        linkId: '1',
        eventTime: t,
        eventId: 'ev',
        payload: const {'amount': '5'},
      );
      final row = link.toTellerTransactionRow();
      expect(row.time, t);
      expect(row.eventId, 'ev');
      expect(row.payload['amount'], '5');
      expect(row.linkedModels, isEmpty);
    });
  });

  group('parseTellerPayloadJson', () {
    test('parses object JSON', () {
      final m = parseTellerPayloadJson('{"date":"2026-01-01","amount":"1"}');
      expect(m['date'], '2026-01-01');
      expect(m['amount'], '1');
    });

    test('rejects empty', () {
      expect(() => parseTellerPayloadJson(''), throwsArgumentError);
      expect(() => parseTellerPayloadJson('   '), throwsArgumentError);
    });

    test('rejects non-object', () {
      expect(() => parseTellerPayloadJson('[1]'), throwsArgumentError);
    });
  });
}
