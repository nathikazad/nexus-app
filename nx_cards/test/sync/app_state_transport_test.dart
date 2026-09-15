import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_cards/sync/remote/kgql_sync_transport.dart';
import 'package:nx_db/app_sync.dart';

void main() {
  test(
    'worker-backed card transport downloads the advertised payload',
    () async {
      var manifests = 0;
      final client = GraphQLClient(
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
                      'projection_version': 1,
                      'collections': {
                        'language': {'hash': 'group'},
                      },
                    }
                  : {
                      'status': 'ready',
                      'revision': 1,
                      'manifest': [
                        {
                          'id': 11,
                          'hash': 's1:card',
                          'collections': ['language'],
                        },
                      ],
                      'items': request.variables['itemIds'] == null
                          ? []
                          : [
                              {
                                'id': 11,
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
      );
      final transport = KgqlCardsSyncTransport(client);
      expect((await transport.cardManifest()).manifest.single.hash, 's1:card');
      final downloaded = await transport.downloadCards({11});
      expect(downloaded.cards.single.card.back, '日');
      expect(manifests, 1);

    },
    skip: !appStateSyncEnabled,
  );
}
