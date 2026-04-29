@Tags(['provider'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart' show QueryOptions;
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_db/riverpod.dart';
import 'package:test/test.dart' show Tags;

import '../../_support/mock_graphql_client.dart';

class _AuthLoggedIn extends AuthController {
  _AuthLoggedIn() : super(initialDelay: Duration.zero, skipBackendPing: true);
  @override
  Future<User?> build() async => User(
        userId: '1',
        personalDomainId: 1,
        homeDomainId: 1,
        preset: BackendPreset.localhost,
      );
}

void main() {
  setUpAll(registerGraphqlFallbacks);

  test('relatedModelsByTypeNameProvider uses model_type name filter + picker struct', () async {
    final mock = MockGraphQLClient();
    QueryOptions? captured;
    when(() => mock.query(any())).thenAnswer((inv) async {
      captured = inv.positionalArguments[0] as QueryOptions;
      return okQueryResult({
        'getKgqlModels': [
          {'id': 1, 'name': 'A', 'model_type_id': 9},
        ],
      });
    });

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_AuthLoggedIn.new),
        graphqlClientProvider.overrideWithValue(mock),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authProvider.future);

    await container.read(
      relatedModelsByTypeNameProvider((modelTypeName: 'Expense', domainId: 1)).future,
    );

    expect(captured, isNotNull);
    expect(captured!.variables['filter'], containsPair('model_type', 'Expense'));
    expect(captured!.variables['struct'], kgqlRelationPickerModelStruct);
    expect(captured!.variables['domainId'], 1);
  });
}
