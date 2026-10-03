import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_time/data/calendar/kgql_calendar_repository.dart';
import 'package:nx_time/domain/calendar/calendar_entry.dart';

class Client extends Mock implements GraphQLClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(QueryOptions(document: gql('query { hello }')));
    registerFallbackValue(MutationOptions(document: gql('mutation { hello }')));
  });
  test('calendar sends range, history and explicit selected domain', () async {
    final client = Client();
    when(() => client.query(any())).thenAnswer(
      (i) async => QueryResult(
        options: i.positionalArguments[0] as QueryOptions,
        source: QueryResultSource.network,
        data: {
          'getKgqlCalendar': {'entries': [], 'unscheduled': []},
        },
      ),
    );
    final repo = KgqlCalendarRepository(client, domainId: 17);
    await repo.load(
      DateTime(2026, 10, 5),
      DateTime(2026, 10, 12),
      actualHistory: true,
    );
    final q =
        verify(() => client.query(captureAny())).captured.single
            as QueryOptions;
    expect(q.variables['domain'], 17);
    expect(q.variables['actual'], true);
    expect(q.variables['from'], '2026-10-05T00:00:00.000');
  });
  test(
    'planning reuses a fresh matching attendance and writes only scheduled times',
    () async {
      final client = Client();
      when(() => client.query(any())).thenAnswer(
        (i) async => QueryResult(
          options: i.positionalArguments[0] as QueryOptions,
          source: QueryResultSource.network,
          data: {
            'getKgqlModels': [
              {
                'id': 2,
                'name': 'Visit',
                'model_type_id': 3,
                'planning_status': 'planned',
                'Event': [
                  {'id': 1, 'name': 'Fair', 'model_type_id': 4},
                ],
              },
            ],
          },
        ),
      );
      when(() => client.mutate(any())).thenAnswer(
        (i) async => QueryResult(
          options: i.positionalArguments[0] as MutationOptions,
          source: QueryResultSource.network,
          data: {
            'setKgqlModels': {
              'json': {'id': 2},
            },
          },
        ),
      );
      final repo = KgqlCalendarRepository(client, domainId: 17);
      await repo.planAttendance(
        CalendarEntry(
          id: 1,
          kind: 'event',
          modelType: 'Event',
          name: 'Fair',
          attributes: {'start_time': '2026-10-05T09:00:00'},
        ),
      );
      final m =
          verify(() => client.mutate(captureAny())).captured.single
              as MutationOptions;
      final input = m.variables['input'] as Map;
      expect(input['domainId'], 17);
      final payload = input['data'] is String ? null : input['data'] as Map;
      expect(payload?['id'], 2);
      final attrs = payload?['attributes'] as List;
      expect(attrs.any((a) => a['key'] == 'start_time'), isFalse);
      expect(
        attrs.any(
          (a) => a['key'] == 'planning_status' && a['value'] == 'planned',
        ),
        isTrue,
      );
    },
  );
}
