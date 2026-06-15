import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_time/data/subscriptions/kgql_model_subscription.dart';

import '../../_support/mock_graphql_client.dart';

void main() {
  setUpAll(() {
    registerGraphqlFallbacks();
    registerFallbackValue(
      SubscriptionOptions(document: gql('subscription { __typename }')),
    );
  });

  test('kgqlModelChangesProvider uses first returned domain', () async {
    final mock = MockGraphQLClient();
    QueryOptions? queryOptions;
    SubscriptionOptions? subscriptionOptions;

    when(() => mock.query(any())).thenAnswer((invocation) async {
      queryOptions = invocation.positionalArguments.single as QueryOptions;
      return okQueryResult({
        'resolveModelTypeDomainOptions': {
          'model_type': 'Action',
          'domains': [
            {'id': 2, 'name': 'Home', 'kind': 'personal', 'source': 'user'},
            {'id': 9, 'name': 'Archive', 'kind': 'personal', 'source': 'user'},
          ],
        },
      });
    });
    when(() => mock.subscribe(any())).thenAnswer((invocation) {
      subscriptionOptions =
          invocation.positionalArguments.single as SubscriptionOptions;
      return Stream<QueryResult>.value(
        QueryResult(
          options: SubscriptionOptions(
            document: gql('subscription { __typename }'),
          ),
          source: QueryResultSource.network,
          data: {
            'subscribeKgqlModels': {
              'operation': 'UPDATE',
              'modelId': 7,
              'modelTypeName': 'Action',
              'domainId': 2,
            },
          },
        ),
      );
    });

    final container = ProviderContainer(
      overrides: [graphqlClientProvider.overrideWithValue(mock)],
    );
    addTearDown(container.dispose);
    final provider = kgqlModelChangesProvider('Action');
    final subscription = container.listen(provider, (_, __) {});
    addTearDown(subscription.close);

    final change = await container.read(provider.future);

    expect(queryOptions!.variables, containsPair('modelTypeName', 'Action'));
    expect(subscriptionOptions!.variables['filter'], {'model_type': 'Action'});
    expect(subscriptionOptions!.variables, containsPair('domainId', 2));
    expect(change.operation, 'UPDATE');
    expect(change.modelId, 7);
    expect(change.domainId, 2);
  });
}
