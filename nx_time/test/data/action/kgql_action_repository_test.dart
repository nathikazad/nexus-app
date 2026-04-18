import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/nx_db.dart';
import 'package:nx_time/data/providers.dart';

import '../../_support/mock_graphql_client.dart';

void main() {
  setUpAll(registerGraphqlFallbacks);

  test('listForCalendarDay loads schema then models', () async {
    final mock = MockGraphQLClient();
    var queryCount = 0;
    when(() => mock.query(any())).thenAnswer((_) async {
      queryCount++;
      if (queryCount == 1) {
        return okQueryResult({
          'getKgqlModelType': [
            {
              'id': 1,
              'name': 'Action',
              'attributes': [
                {'key': 'start_time', 'value_type': 'datetime'},
                {'key': 'end_time', 'value_type': 'datetime'},
              ],
            },
          ],
        });
      }
      return okQueryResult({
        'getKgqlModels': [
          {
            'id': 7,
            'name': 'Morning Run',
            'model_type_id': 3,
            'start_time': '2026-04-18T08:00:00.000',
            'end_time': '2026-04-18T09:00:00.000',
            'model_type': {'id': 3, 'name': 'Workout', 'type_kind': 'base'},
          },
        ],
      });
    });

    final container = ProviderContainer(
      overrides: [
        graphqlClientProvider.overrideWithValue(mock),
      ],
    );
    addTearDown(container.dispose);

    final repo = container.read(actionRepositoryProvider);
    final list = await repo.listForCalendarDay(DateTime(2026, 4, 18));
    expect(list.length, 1);
    expect(list.first.name, 'Morning Run');
    expect(queryCount, 2);
  });
}
