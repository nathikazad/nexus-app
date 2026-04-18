import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_time/data/providers.dart';

import '../../_support/mock_graphql_client.dart';

void main() {
  setUpAll(registerGraphqlFallbacks);

  test('getActionRoot returns Action model type', () async {
    final mock = MockGraphQLClient();
    when(() => mock.query(any())).thenAnswer((_) async => okQueryResult({
          'getKgqlModelType': [
            {
              'id': 1,
              'name': 'Action',
              'attributes': [
                {'key': 'start_time', 'value_type': 'datetime'},
              ],
            },
          ],
        }));

    final container = ProviderContainer(
      overrides: [
        graphqlClientProvider.overrideWithValue(mock),
      ],
    );
    addTearDown(container.dispose);

    final repo = container.read(kgqlActionSchemaRepositoryProvider);
    final mt = await repo.getActionRoot();
    expect(mt.name, 'Action');
  });
}
