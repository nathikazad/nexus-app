@Tags(['provider'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart' show QueryOptions;
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_db/riverpod.dart';
import 'package:test/test.dart' show Tags;

import '../../_support/mock_graphql_client.dart';

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
      overrides: [graphqlClientProvider.overrideWithValue(mock)],
    );
    addTearDown(container.dispose);

    await container.read(relatedModelsByTypeNameProvider('Expense').future);

    expect(captured, isNotNull);
    expect(captured!.variables['filter'], containsPair('model_type', 'Expense'));
    expect(captured!.variables['struct'], kgqlRelationPickerModelStruct);
  });
}
