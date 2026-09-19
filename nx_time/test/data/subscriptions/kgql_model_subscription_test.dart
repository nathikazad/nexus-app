import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_time/data/subscriptions/kgql_model_subscription.dart';

import '../../_support/mock_graphql_client.dart';

class _TestAuth extends AuthController {
  _TestAuth(this.user);
  final User? user;

  @override
  Future<User?> build() async => user;
}

void main() {
  setUpAll(() {
    registerGraphqlFallbacks();
    registerFallbackValue(
      SubscriptionOptions(document: gql('subscription { __typename }')),
    );
  });

  test('kgqlModelChangesProvider uses the selected session domain', () async {
    final mock = MockGraphQLClient();
    SubscriptionOptions? subscriptionOptions;

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
              'domainId': 9,
            },
          },
        ),
      );
    });

    final container = ProviderContainer(
      overrides: [
        graphqlClientProvider.overrideWithValue(mock),
        authProvider.overrideWith(
          () => _TestAuth(
            User(userId: '1', preset: BackendPreset.localhost, domainId: 9),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authProvider.future);
    final provider = kgqlModelChangesProvider('Action');
    final subscription = container.listen(provider, (_, __) {});
    addTearDown(subscription.close);

    final change = await container.read(provider.future);

    verifyNever(() => mock.query(any()));
    expect(subscriptionOptions!.variables['filter'], {'model_type': 'Action'});
    expect(subscriptionOptions!.variables, containsPair('domainId', 9));
    expect(change.operation, 'UPDATE');
    expect(change.modelId, 7);
    expect(change.domainId, 9);
  });

  for (final user in <User?>[
    null,
    User(userId: '1', preset: BackendPreset.localhost),
  ]) {
    test(
      'does not subscribe without a selected domain (user: $user)',
      () async {
        final mock = MockGraphQLClient();
        final container = ProviderContainer(
          overrides: [
            graphqlClientProvider.overrideWithValue(mock),
            authProvider.overrideWith(() => _TestAuth(user)),
          ],
        );
        addTearDown(container.dispose);
        await container.read(authProvider.future);
        final subscription = container.listen(
          kgqlModelChangesProvider('Action'),
          (_, __) {},
        );
        addTearDown(subscription.close);
        await container.pump();
        verifyNever(() => mock.query(any()));
        verifyNever(() => mock.subscribe(any()));
      },
    );
  }
}
