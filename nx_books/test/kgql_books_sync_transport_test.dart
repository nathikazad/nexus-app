import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_books/data/book/kgql_books_sync_transport.dart';

void main() {
  test('slow manifest and batch outlive the ordinary client timeout', () async {
    final calls = <Map<String, dynamic>>[];
    final client = GraphQLClient(
      cache: GraphQLCache(store: InMemoryStore()),
      queryRequestTimeout: const Duration(milliseconds: 5),
      link: Link.function((request, [forward]) async* {
        calls.add(request.variables);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        yield Response(
          response: const {},
          data: {
            '__typename': 'Query',
            'syncDocuments': {
              'manifest': [
                {'id': 42, 'model_type': 'Book', 'hash': 'v2:hash'},
              ],
              'documents': [],
              'deleted_ids': [],
              'topic_tags': [],
            },
          },
        );
      }),
    );
    final transport = KgqlBooksSyncTransport(client);
    expect((await transport.manifest()).manifest.single.id, 42);
    await transport.download({42});
    expect(calls.length, 2);
    expect(calls.first['manifestOnly'], true);
    expect(calls.last['documentIds'], [42]);
    expect(KgqlBooksSyncTransport.requestTimeout, const Duration(minutes: 5));
  });
}
