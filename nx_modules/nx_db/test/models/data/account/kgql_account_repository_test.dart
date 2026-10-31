@Tags(['repository'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/account.dart';
import 'package:test/test.dart' show Tags;

import '../../../_support/mock_graphql_client.dart';

Future<User> _user() async =>
    User(userId: '1', preset: BackendPreset.localhost);

void main() {
  setUpAll(registerGraphqlFallbacks);

  test('updatePreference writes users.preferences', () async {
    final mock = MockGraphQLClient();
    MutationOptions? captured;
    when(() => mock.mutate(any())).thenAnswer((inv) async {
      captured = inv.positionalArguments[0] as MutationOptions;
      return QueryResult(
        options: MutationOptions(document: gql('mutation { __typename }')),
        source: QueryResultSource.network,
        data: {
          'updateUserById': {
            'user': {
              'id': 1,
              'preferences': {
                'model_type_colors': {'Yoga': '#00FF00'},
              },
            },
          },
        },
      );
    });

    final repo = KgqlAccountRepository(
      client: mock,
      loadAuthenticatedUser: _user,
    );
    await repo.updatePreference(
      const AccountProfile(
        id: 5,
        name: 'Nathik',
        preferences: <String, dynamic>{},
      ),
      <String, dynamic>{
        'other': 1,
        'model_type_colors': <String, dynamic>{
          'Yoga': '#00FF00',
          'Sleep': '#AABBCC',
        },
      },
    );

    verify(() => mock.mutate(any())).called(1);
    expect(captured!.variables['id'], 1);
    final pref = captured!.variables['preferences'] as Map<String, dynamic>;
    expect(pref['other'], 1);
    final mtc = pref['model_type_colors'] as Map<String, dynamic>;
    expect(mtc['Yoga'], '#00FF00');
    expect(mtc['Sleep'], '#AABBCC');
  });

  test(
    'getCurrent reads users directly without any Person model query',
    () async {
      final mock = MockGraphQLClient();
      QueryOptions? captured;
      when(() => mock.query(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as QueryOptions;
        return okQueryResult({
          'allUsers': {
            'nodes': [
              {
                'id': 1,
                'name': 'Nathik',
                'description': 'Account biography',
                'preferences': {
                  'goal_order': [7, 3],
                  'model_type_colors': {'Yoga': '#00FF00'},
                },
              },
            ],
          },
        });
      });
      final repo = KgqlAccountRepository(
        client: mock,
        loadAuthenticatedUser: _user,
      );
      final account = await repo.getCurrent();
      expect(account?.id, 1);
      expect(account?.description, 'Account biography');
      expect(account?.preferences['goal_order'], [7, 3]);
      verify(() => mock.query(any())).called(1);
      expect(captured!.fetchPolicy, FetchPolicy.networkOnly);
      expect(captured!.document.toString(), isNot(contains('personModelId')));
    },
  );
}
