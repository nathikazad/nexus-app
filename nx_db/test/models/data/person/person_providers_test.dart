@Tags(['provider'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/person.dart';
import 'package:nx_db/riverpod.dart';
import 'package:test/test.dart' show Tags;

import '../../../_support/mock_graphql_client.dart';

void main() {
  setUpAll(registerGraphqlFallbacks);

  test('personRepositoryProvider returns KgqlPersonRepository', () {
    final mock = MockGraphQLClient();
    when(() => mock.query(any())).thenAnswer(
      (_) async => okQueryResult({'getKgqlModels': <dynamic>[]}),
    );
    final container = ProviderContainer(
      overrides: [graphqlClientProvider.overrideWithValue(mock)],
    );
    addTearDown(container.dispose);

    final repo = container.read(personRepositoryProvider);
    expect(repo, isA<KgqlPersonRepository>());
  });
}
