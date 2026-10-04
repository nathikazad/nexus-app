import 'package:nx_db/src/core/client/graphql_client.dart'
    show bindTestClientDomain;
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_cards/sync/remote/kgql_sync_transport.dart';
import 'package:nx_db/app_sync.dart';

void main() {
  test(
    'worker-backed card transport downloads the advertised payload',
    () async {
      var manifests = 0;
      final client = bindTestClientDomain(
        GraphQLClient(
          cache: GraphQLCache(store: InMemoryStore()),
          link: Link.function((request, [forward]) async* {
            final state = !request.variables.containsKey('revision');
            if (!state && request.variables['itemIds'] == null) manifests++;
            yield Response(
              response: const {},
              data: {
                state ? 'appSyncState' : 'appSyncSnapshot': state
                    ? {
                        'status': 'ready',
                        'revision': 1,
                        'root_hash': 'root',
                        'projection_version': 3,
                        'collections': {
                          '': {
                            'hash': 'group',
                            'parent': null,
                            'count': 1,
                            'child_count': 0,
                          },
                        },
                      }
                    : {
                        'status': 'ready',
                        'revision': 1,
                        'projection_version': 3,
                        'collections': {},
                        'manifest': [
                          {
                            'id': 'model:11',
                            'hash': 's1:card',
                            'collections': [''],
                          },
                        ],
                        'items': request.variables['itemIds'] == null
                            ? []
                            : [
                                {
                                  'id': 'model:11',
                                  'hash': 's1:card',
                                  'payload': {
                                    'id': 11,
                                    'name': 'day',
                                    'model_type_id': 3,
                                    'model_type': {'id': 3, 'name': 'Word'},
                                    'attributes': {
                                      'card_details': {
                                        'front': 'day',
                                        'back': '日',
                                      },
                                    },
                                    'tags': {
                                      'Language': ['Chinese'],
                                    },
                                    'relations': [],
                                  },
                                },
                              ],
                      },
              },
            );
          }),
        ),
        1,
      );
      final transport = KgqlCardsSyncTransport(client);
      expect(
        (await transport.cardManifest()).manifest.single.hash,
        startsWith('v1:'),
      );
      final downloaded = await transport.downloadCards({11});
      expect(downloaded.cards.single.card.back, '日');
      expect(manifests, 1);
    },
    skip: !appStateSyncEnabled,
  );
}
