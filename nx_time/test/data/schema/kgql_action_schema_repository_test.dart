import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_time/data/providers.dart';

import '../../_support/mock_graphql_client.dart';

class _AuthLoggedIn extends AuthController {
  _AuthLoggedIn() : super(initialDelay: Duration.zero, skipBackendPing: true);
  @override
  Future<User?> build() async =>
      User(userId: '1', preset: BackendPreset.localhost);
}

void main() {
  setUpAll(registerGraphqlFallbacks);

  test('getActionRoot returns Action model type', () async {
    final mock = MockGraphQLClient();
    when(() => mock.query(any())).thenAnswer(
      (_) async => okQueryResult({
        'getKgqlModelType': [
          {
            'id': 1,
            'name': 'Action',
            'attributes': [
              {'key': 'start_time', 'value_type': 'datetime'},
            ],
          },
        ],
      }),
    );

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_AuthLoggedIn.new),
        graphqlClientProvider.overrideWithValue(mock),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authProvider.future);

    final repo = container.read(kgqlActionSchemaRepositoryProvider);
    final mt = await repo.getActionRoot();
    expect(mt.name, 'Action');
  });
}
