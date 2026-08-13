@Tags(['auth'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_db/auth.dart';
import 'package:test/test.dart' show Tags;

void main() {
  test('pingGraphqlBackend succeeds on 200 JSON without GraphQL errors',
      () async {
    final mock = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.headers['Content-Type'], 'application/json');
      expect(request.headers['x-user-id'], '42');
      return http.Response('{"data":{"__typename":"Query"}}', 200);
    });

    await pingGraphqlBackend(
      graphqlHttpUrl: 'http://127.0.0.1:5999/graphql',
      userId: '42',
      httpClient: mock,
    );
  });

  test('pingGraphqlBackend throws on GraphQL errors payload', () async {
    final mock = MockClient((request) async {
      return http.Response('{"errors":[{"message":"bad"}]}', 200);
    });

    expect(
      () => pingGraphqlBackend(
        graphqlHttpUrl: 'http://127.0.0.1:5999/graphql',
        userId: '1',
        httpClient: mock,
      ),
      throwsA(isA<Exception>()),
    );
  });
}
