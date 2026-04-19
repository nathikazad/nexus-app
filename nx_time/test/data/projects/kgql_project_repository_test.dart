import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_time/data/projects/kgql_project_repository.dart';
import 'package:nx_time/data/projects/project_attr_keys.dart';

import '../../_support/mock_graphql_client.dart';

void main() {
  setUpAll(registerGraphqlFallbacks);

  test('linkChildProject sends set_kgql_models with Project link', () async {
    final mock = MockGraphQLClient();
    when(() => mock.mutate(any())).thenAnswer((_) async => okMutationResult({
          'setKgqlModels': {
            'json': {'id': 99},
          },
        }));

    final repo = KgqlProjectRepository(
      client: mock,
      loadProjectSchema: () async => throw UnsupportedError('not used'),
    );

    final id = await repo.linkChildProject(parentId: 10, childId: 20);
    expect(id, 99);

    final captured =
        verify(() => mock.mutate(captureAny())).captured.single as MutationOptions;
    final input = captured.variables!['input'] as Map<String, dynamic>;
    final data = input['data'] as Map<String, dynamic>;
    expect(data['id'], 10);
    final rels = data['relations'] as List<dynamic>;
    expect(rels.single['model_type'], kProjectRelationKey);
    expect(rels.single['link'], [20]);
  });

  test('listAll loads schema then models', () async {
    final mock = MockGraphQLClient();
    var queryCount = 0;
    when(() => mock.query(any())).thenAnswer((_) async {
      queryCount++;
      if (queryCount == 1) {
        return okQueryResult({
          'getKgqlModelType': [
            {
              'id': 1,
              'name': 'Project',
              'attributes': [],
            },
          ],
        });
      }
      return okQueryResult({
        'getKgqlModels': [
          {
            'id': 7,
            'name': 'Nexus App',
            'model_type_id': 3,
            'model_type': {'id': 3, 'name': 'Project', 'type_kind': 'base'},
          },
        ],
      });
    });

    final repo = KgqlProjectRepository(
      client: mock,
      loadProjectSchema: () async {
        final r = await mock.query(
          QueryOptions(document: gql('query { __typename }')),
        );
        final rows = r.data!['getKgqlModelType'] as List<dynamic>;
        return ModelType.fromJson(
          Map<String, dynamic>.from(rows.first as Map),
        );
      },
    );

    final list = await repo.listAll();
    expect(list.length, 1);
    expect(list.first.name, 'Nexus App');
    expect(queryCount, 2);
  });
}
