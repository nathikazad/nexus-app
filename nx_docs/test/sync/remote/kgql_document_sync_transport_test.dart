import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nx_docs/sync/remote/kgql_document_sync_transport.dart';
import 'package:nx_docs/sync/sync_models.dart';

final class _MockGraphQLClient extends Mock implements GraphQLClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(QueryOptions(document: gql('query { __typename }')));
  });

  test('maps a changed KGQL payload into the domain sync bundle', () async {
    final client = _MockGraphQLClient();
    when(() => client.query(any())).thenAnswer(
      (_) async => QueryResult(
        options: QueryOptions(document: gql('query { __typename }')),
        source: QueryResultSource.network,
        data: const <String, Object?>{
          'syncDocuments': <String, Object?>{
            'documents': <Object?>[
              <String, Object?>{
                'id': 42,
                'hash': 'server-hash',
                'document': <String, Object?>{
                  'id': 42,
                  'name': 'Synced title',
                  'description': 'Excerpt',
                  'model_type_id': 7,
                  'created_at': '2026-07-29T10:00:00',
                  'updated_at': '2026-07-30T10:00:00',
                  'model_type': <String, Object?>{'id': 7, 'name': 'Document'},
                  'attributes': <String, Object?>{
                    'document': 'Synced body',
                    'json_document': <String, Object?>{
                      'format': 'appflowy_document',
                      'document': <String, Object?>{
                        'type': 'page',
                        'children': <Object?>[],
                      },
                    },
                  },
                  'tags': <String, Object?>{},
                  'relations': <Object?>[],
                },
              },
            ],
            'deleted_ids': <Object?>[9],
          },
        },
      ),
    );

    final bundle = await KgqlDocumentSyncTransport(
      client,
    ).syncDocuments(manifest: const <DocumentManifestEntry>[]);

    expect(bundle.documents.single.document.id, 42);
    expect(bundle.documents.single.document.document, 'Synced body');
    expect(bundle.documents.single.serverHash, 'server-hash');
    expect(bundle.deletedIds, <int>[9]);
  });
}
