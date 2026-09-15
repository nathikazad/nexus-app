import 'package:nx_db/src/core/client/graphql_client.dart'
    show bindTestClientDomain;
import '../../nx_modules/nx_db/test/support/app_sync_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_books/data/book/kgql_books_sync_transport.dart';

void main() {
  test('slow manifest and batch outlive the ordinary client timeout', () async {
    final calls = <Map<String, dynamic>>[];
    final client = bindTestClientDomain(
      GraphQLClient(
        cache: GraphQLCache(store: InMemoryStore()),
        queryRequestTimeout: const Duration(milliseconds: 5),
        link: Link.function((request, [forward]) async* {
          calls.add(request.variables);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          yield Response(
            response: const {},
            data: appSyncFixture(request.variables, [
              {
                'id': 42,
                'hash': 's1:hash',
                'payload': {
                  'id': 42,
                  'name': 'Book',
                  'model_type': {'id': 1, 'name': 'Book'},
                  'attributes': {},
                },
              },
            ]),
          );
        }),
      ),
      1,
    );
    final transport = KgqlBooksSyncTransport(client);
    expect((await transport.manifest()).manifest.single.id, 42);
    await transport.download({42});
    expect(calls.length, 4);
    expect(calls.first['app'], 'books');
    expect(calls.last['itemIds'], [42]);
    expect(
      client.cache.store.toMap(),
      isEmpty,
      reason: 'Bulk sync payloads belong only in the offline store',
    );
    expect(KgqlBooksSyncTransport.requestTimeout, const Duration(minutes: 5));
  });
}
