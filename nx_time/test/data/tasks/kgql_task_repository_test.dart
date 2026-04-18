import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_time/data/providers.dart';

import '../../_support/mock_graphql_client.dart';

void main() {
  setUpAll(registerGraphqlFallbacks);

  test('listForPicker loads Task rows', () async {
    final mock = MockGraphQLClient();
    when(() => mock.query(any())).thenAnswer((_) async => okQueryResult({
          'getKgqlModels': [
            {'id': 1, 'name': 'Refactor token validation', 'model_type_id': 9},
          ],
        }));

    final container = ProviderContainer(
      overrides: [
        graphqlClientProvider.overrideWithValue(mock),
      ],
    );
    addTearDown(container.dispose);

    final repo = container.read(taskRepositoryProvider);
    final tasks = await repo.listForPicker();
    expect(tasks.length, 1);
    expect(tasks.first.name, 'Refactor token validation');
  });
}
