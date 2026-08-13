import 'package:flutter_test/flutter_test.dart';
import 'package:gql/language.dart' show printNode;
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/cards.dart';
import 'package:nx_db/kgql.dart';

import '../_support/mock_graphql_client.dart';

void main() {
  setUpAll(registerGraphqlFallbacks);

  test('mutateCardLibrary sends timestamp and parses canonical entity',
      () async {
    final client = MockGraphQLClient();
    MutationOptions? captured;
    when(() => client.mutate(any())).thenAnswer((invocation) async {
      captured = invocation.positionalArguments.single as MutationOptions;
      return QueryResult(
        options: MutationOptions(document: gql('mutation { __typename }')),
        source: QueryResultSource.network,
        data: const <String, Object?>{
          'mutateCardLibrary': <String, Object?>{
            'status': 'APPLIED',
            'id': 42,
            'updated_at': '2026-08-04T12:00:00',
            'entity': <String, Object?>{'id': 42, 'name': 'Front'},
          },
        },
      );
    });

    final result = await mutateCardLibrary(
      client,
      SetModelRequest(id: 42, name: 'Front'),
      clientUpdatedAt: DateTime.utc(2026, 8, 4, 12),
    );

    expect(printNode(captured!.document), contains('mutateCardLibrary'));
    expect(captured!.variables['clientUpdatedAt'], '2026-08-04T12:00:00.000Z');
    expect(result.status, CardLibraryMutationStatus.applied);
    expect(result.entityId, 42);
    expect(result.entity?['name'], 'Front');
  });
}
