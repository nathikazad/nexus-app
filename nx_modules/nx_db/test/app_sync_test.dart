import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/app_sync.dart';

void main() {
  test(
    'browser refresh skips equal roots and retries failed refreshes',
    () async {
      var root = 'one';
      final client = AppSyncClient(
        GraphQLClient(
          cache: GraphQLCache(store: InMemoryStore()),
          link: Link.function((request, [forward]) async* {
            yield Response(
              data: {
                'appSyncState': {
                  'status': 'ready',
                  'projection_version': 1,
                  'root_hash': root,
                },
              },
              response: const {},
            );
          }),
        ),
        'docs',
      );
      var refreshes = 0;
      Future<void> refresh() async {
        refreshes++;
      }

      await client.refreshIfChanged(refresh);
      await client.refreshIfChanged(refresh);
      expect(refreshes, 1);
      root = 'two';
      await expectLater(
        client.refreshIfChanged(() async {
          throw StateError('offline');
        }),
        throwsStateError,
      );
      await client.refreshIfChanged(refresh);
      expect(refreshes, 2);
    },
  );

  for (final app in ['docs', 'books']) {
    test(
      '$app maps revision snapshots and skips unchanged manifests',
      () async {
        var manifests = 0;
        var bodies = 0;
        final client = GraphQLClient(
          cache: GraphQLCache(store: InMemoryStore()),
          link: Link.function((request, [forward]) async* {
            expect(request.variables['app'], app);
            final state = !request.variables.containsKey('revision');
            if (!state) {
              if (request.variables['itemIds'] == null)
                manifests++;
              else
                bodies++;
            }
            yield Response(
              data: {
                state ? 'appSyncState' : 'appSyncSnapshot': state
                    ? {
                        'status': 'ready',
                        'revision': 3,
                        'root_hash': 'root3',
                        'projection_version': 1,
                        'collections': {
                          'document:42': {
                            'hash': 'group3',
                            'metadata': {'kind': 'Document', 'name': 'Book'},
                          },
                        },
                      }
                    : {
                        'status': 'ready',
                        'revision': 3,
                        'manifest': [
                          {
                            'id': 42,
                            'hash': 's1:body',
                            'model_type': 'Book',
                            'collections': ['document:42'],
                          },
                        ],
                        'items': request.variables['itemIds'] == null
                            ? []
                            : [
                                {
                                  'id': 42,
                                  'hash': 's1:body',
                                  'payload': {
                                    'id': 42,
                                    'name': 'Book',
                                    'model_type': {'id': 7, 'name': 'Book'},
                                    'attributes': {},
                                  },
                                },
                              ],
                      },
              },
              response: const {},
            );
          }),
        );
        final sync = AppSyncClient(client, app);
        final first = (await sync.documents(
          localManifest: [],
          manifestOnly: true,
        ))!;
        expect(first.manifest.single.modelType, 'Book');
        expect(first.documents, isEmpty);
        final downloaded = (await sync.documents(
          localManifest: [],
          ids: {42},
        ))!;
        expect(downloaded.documents.single.document['name'], 'Book');
        await sync.documents(
          localManifest: [
            {'id': 42, 'hash': 's1:body'},
          ],
        );
        expect(manifests, 1);
        expect(bodies, 1);
        expect(client.cache.store.toMap(), isEmpty);
      },
      skip: !appStateSyncEnabled,
    );
  }
}
