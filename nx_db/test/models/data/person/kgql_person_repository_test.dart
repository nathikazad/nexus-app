@Tags(['repository'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/person.dart';
import 'package:test/test.dart' show Tags;

import '../../../_support/mock_graphql_client.dart';

Future<User> _user() async => User(
      userId: '1',
      preset: BackendPreset.localhost,
    );

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

    final repo = KgqlPersonRepository(
      client: mock,
      loadAuthenticatedUser: _user,
    );
    await repo.updatePreference(
      const Person(
        id: 5,
        name: 'Nathik',
        preference: <String, dynamic>{},
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

  test('getMain reads linked Person plus users.preferences', () async {
    final mock = MockGraphQLClient();
    var queryCount = 0;
    when(() => mock.query(any())).thenAnswer((_) async {
      queryCount += 1;
      if (queryCount == 1) {
        return okQueryResult({
          'allUsers': {
            'nodes': [
              {
                'id': 1,
                'name': 'Nathik',
                'personModelId': 5,
                'preferences': {
                  'model_type_colors': {'Yoga': '#00FF00'},
                },
              },
            ],
          },
        });
      }
      return okQueryResult({
        'getKgqlModels': [
          {
            'id': 5,
            'name': 'Nathik',
            'description': 'Main user',
            'model_type_id': 4,
          },
        ],
      });
    });

    final repo = KgqlPersonRepository(
      client: mock,
      loadAuthenticatedUser: _user,
    );

    final person = await repo.getMain();
    expect(person?.id, 5);
    expect(person?.name, 'Nathik');
    expect(person?.preference['model_type_colors'], {'Yoga': '#00FF00'});
  });
}
