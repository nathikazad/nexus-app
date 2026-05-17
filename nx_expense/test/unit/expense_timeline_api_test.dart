import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_expense/data/teller/expense_timeline_api.dart';
import 'package:nx_expense/domain/teller/teller_link.dart';

class _MockGraphQLClient extends Mock implements GraphQLClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      MutationOptions(document: gql('mutation { __typename }')),
    );
  });

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
                  'eventType': kTellerTimelineEventType,
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
      expect(l.eventType, kTellerTimelineEventType);
      expect(l.isTellerTimelineEvent, isTrue);
      expect(l.isBillImageEvent, isFalse);
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

  group('TellerExpenseLink.toTellerTransaction', () {
    test('maps fields; linkedModels empty', () {
      final t = DateTime.utc(2026, 4, 1, 12);
      final link = TellerExpenseLink(
        linkId: '1',
        eventTime: t,
        eventId: 'ev',
        payload: const {'amount': '5'},
        eventType: kTellerTimelineEventType,
      );
      final row = link.toTellerTransaction();
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

  group('linkExpenseToTimelineEvent', () {
    test('sends eventTime as local timestamp without timezone', () async {
      final mock = _MockGraphQLClient();
      when(() => mock.mutate(any())).thenAnswer(
        (_) async => QueryResult(
          options: MutationOptions(document: gql('mutation { __typename }')),
          source: QueryResultSource.network,
          data: const {
            'createModelTimelineEventLink': {
              'modelTimelineEventLink': {'id': 1},
            },
          },
        ),
      );

      await linkExpenseToTimelineEvent(
        mock,
        modelId: 3295,
        eventTime: DateTime(2026, 5, 16),
        eventId: '16845',
      );

      final captured =
          verify(() => mock.mutate(captureAny())).captured.single
              as MutationOptions;
      expect(
        captured.variables['input']['modelTimelineEventLink']['eventTime'],
        '2026-05-16T00:00:00',
      );
    });

    test('formats local timestamps without converting UTC instances', () {
      expect(
        formatTimelineLocalTimestamp(DateTime.utc(2026, 5, 16, 7)),
        '2026-05-16T07:00:00',
      );
      expect(
        formatTimelineLocalTimestamp(DateTime(2026, 5, 16, 0, 0, 0, 123, 456)),
        '2026-05-16T00:00:00.123456',
      );
    });

    test('logs mutation and error when link mutation fails', () async {
      final mock = _MockGraphQLClient();
      final exception = OperationException(
        graphqlErrors: [
          const GraphQLError(
            message: 'duplicate timeline link',
            extensions: {'code': '23505'},
          ),
        ],
      );
      when(() => mock.mutate(any())).thenAnswer(
        (_) async => QueryResult(
          options: MutationOptions(document: gql('mutation { __typename }')),
          source: QueryResultSource.network,
          exception: exception,
        ),
      );

      final logs = <String>[];
      await expectLater(
        runZoned(
          () => linkExpenseToTimelineEvent(
            mock,
            modelId: 3295,
            eventTime: DateTime.utc(2026, 5, 15),
            eventId: 'evt-1',
          ),
          zoneSpecification: ZoneSpecification(
            print: (_, __, ___, line) => logs.add(line),
          ),
        ),
        throwsA(isA<OperationException>()),
      );

      final out = logs.join('\n');
      expect(
        out,
        contains('Timeline mutation error: CreateModelTimelineEventLink'),
      );
      expect(out, contains('mutation CreateModelTimelineEventLink'));
      expect(out, contains('"modelId": 3295'));
      expect(out, contains('"eventId": "evt-1"'));
      expect(out, contains('duplicate timeline link'));
      expect(out, contains('"code": "23505"'));
    });
  });
}
