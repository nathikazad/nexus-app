import '../../../../nx_modules/nx_db/test/support/app_sync_fixture.dart';
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

  test(
    'manifest request uses the shared server API and bulk timeout',
    () async {
      final client = _MockGraphQLClient();
      when(() => client.query(any())).thenAnswer((call) async {
        final options = call.positionalArguments.single as QueryOptions;
        expect(options.variables['app'], 'docs');
        expect(options.queryRequestTimeout, const Duration(seconds: 30));
        return QueryResult(
          options: options,
          source: QueryResultSource.network,
          data: appSyncFixture(options.variables, [
            {
              'id': 1,
              'hash': 'h',
              'payload': {
                'id': 1,
                'model_type': {'name': 'Document'},
              },
            },
          ]),
        );
      });
      final bundle = await KgqlDocumentSyncTransport(
        client,
      ).syncDocuments(manifest: [], manifestOnly: true);
      expect(bundle.manifest.single.serverHash, 'h');
      expect(bundle.documents, isEmpty);
    },
  );
  test('maps a changed KGQL payload into the domain sync bundle', () async {
    final client = _MockGraphQLClient();
    when(() => client.query(any())).thenAnswer(
      (call) async => QueryResult(
        options: QueryOptions(document: gql('query { __typename }')),
        source: QueryResultSource.network,
        data: _fixture(
          (call.positionalArguments.single as QueryOptions).variables,
          const <String, Object?>{
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
                    'model_type': <String, Object?>{
                      'id': 7,
                      'name': 'Document',
                    },
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
      ),
    );

    final bundle = await KgqlDocumentSyncTransport(client).syncDocuments(
      manifest: const <DocumentManifestEntry>[
        DocumentManifestEntry(documentId: 9),
      ],
    );

    expect(bundle.documents.single.document.id, 42);
    expect(bundle.documents.single.document.document, 'Synced body');
    expect(bundle.documents.single.serverHash, 'server-hash');
    expect(bundle.deletedIds, <int>[9]);
  });
}

Map<String, dynamic> _fixture(
  Map<String, dynamic> variables,
  Map<String, Object?> legacy,
) {
  final data = legacy['syncDocuments'] as Map;
  return appSyncFixture(variables, [
    for (final item in data['documents'] as List)
      {'id': item['id'], 'hash': item['hash'], 'payload': item['document']},
  ]);
}
