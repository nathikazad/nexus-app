import 'package:flutter_test/flutter_test.dart';
import 'package:gql/language.dart' show printNode;
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_db/documents.dart';
import 'package:nx_db/kgql.dart';

import '../_support/mock_graphql_client.dart';

void main() {
  setUpAll(registerGraphqlFallbacks);

  test('mutateDocument sends the client timestamp and parses the hash',
      () async {
    final client = MockGraphQLClient();
    MutationOptions? captured;
    when(() => client.mutate(any())).thenAnswer((invocation) async {
      captured = invocation.positionalArguments.single as MutationOptions;
      return QueryResult(
        options: MutationOptions(document: gql('mutation { __typename }')),
        source: QueryResultSource.network,
        data: const <String, Object?>{
          'mutateDocument': <String, Object?>{
            'status': 'APPLIED',
            'id': 42,
            'updated_at': '2026-07-30T12:00:00',
            'sync_hash': 'abc123',
          },
        },
      );
    });

    final result = await mutateDocument(
      client,
      SetModelRequest(
        id: 42,
        attributes: <SetModelAttribute>[
          SetModelAttribute(key: 'document', value: 'Changed'),
        ],
      ),
      clientUpdatedAt: DateTime.utc(2026, 7, 30, 12),
    );

    expect(printNode(captured!.document), contains('mutateDocument'));
    expect(captured!.variables['clientUpdatedAt'], '2026-07-30T12:00:00.000Z');
    expect(result.status, DocumentMutationStatus.applied);
    expect(result.documentId, 42);
    expect(result.syncHash, 'abc123');
  });

  test('syncDocuments sorts ids and parses changed and deleted rows', () async {
    final client = MockGraphQLClient();
    QueryOptions? captured;
    when(() => client.query(any())).thenAnswer((invocation) async {
      captured = invocation.positionalArguments.single as QueryOptions;
      return QueryResult(
        options: QueryOptions(document: gql('query { __typename }')),
        source: QueryResultSource.network,
        data: const <String, Object?>{
          'syncDocuments': <String, Object?>{
            'documents': <Object?>[
              <String, Object?>{
                'id': 7,
                'hash': 'new-hash',
                'document': <String, Object?>{
                  'id': 7,
                  'name': 'Seven',
                  'model_type_id': 3,
                },
              },
            ],
            'deleted_ids': <Object?>[8],
          },
        },
      );
    });

    final result = await syncDocuments(
      client,
      manifest: const <Map<String, Object?>>[
        <String, Object?>{'id': 7, 'hash': 'old-hash'},
      ],
      documentIds: <int>{9, 7},
    );

    expect(printNode(captured!.document), contains('syncDocuments'));
    expect(captured!.variables['documentIds'], <int>[7, 9]);
    expect(result.documents.single.documentId, 7);
    expect(result.documents.single.syncHash, 'new-hash');
    expect(result.deletedIds, <int>[8]);
  });
}
