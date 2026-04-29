@Tags(['repository'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/person.dart';
import 'package:test/test.dart' show Tags;

import '../../../_support/mock_graphql_client.dart';

void main() {
  setUpAll(registerGraphqlFallbacks);

  test('updatePreference writes full preference map', () async {
    final mock = MockGraphQLClient();
    MutationOptions? captured;
    when(() => mock.mutate(any())).thenAnswer((inv) async {
      captured = inv.positionalArguments[0] as MutationOptions;
      return QueryResult(
        options: MutationOptions(document: gql('mutation { __typename }')),
        source: QueryResultSource.network,
        data: {
          'setKgqlModels': {'json': '{"id": 1}'},
        },
      );
    });

    final repo = KgqlPersonRepository(
      client: mock,
      loadPersonSchema: () => throw UnimplementedError(),
      domainId: 1,
    );
    await repo.updatePreference(
      const Person(
        id: 5,
        name: 'Main User',
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
    final input = captured!.variables['input'] as Map<String, dynamic>;
    final data = input['data'] as Map<String, dynamic>;
    expect(data['id'], 5);
    expect(data['model_type'], 'Person');
    expect(data['name'], 'Main User');
    final attrs = data['attributes'] as List<dynamic>;
    expect(attrs.length, 1);
    expect(attrs[0]['key'], 'preference');
    final pref = attrs[0]['value'] as Map<String, dynamic>;
    expect(pref['other'], 1);
    final mtc = pref['model_type_colors'] as Map<String, dynamic>;
    expect(mtc['Yoga'], '#00FF00');
    expect(mtc['Sleep'], '#AABBCC');
  });
}
