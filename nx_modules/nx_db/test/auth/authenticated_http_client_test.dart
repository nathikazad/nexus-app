import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_db/auth.dart';

void main() {
  test('direct mode replaces forged identity with the session user', () async {
    late http.Request received;
    final inner = MockClient((request) async {
      received = request;
      return http.Response('ok', 200);
    });
    final client = NexusAuthenticatedClient(
      preset: BackendPreset.piTailscale,
      userId: '7',
      inner: inner,
    );

    final response = await client.post(
      Uri.parse('http://100.108.43.37/test'),
      headers: {'X-User-Id': '999', 'content-type': 'application/json'},
      body: '{"ok":true}',
    );

    expect(response.statusCode, 200);
    expect(received.headers['x-user-id'], '7');
    expect(received.body, '{"ok":true}');
    client.close();
  });

  test('hosted mode refreshes and retries exactly once after 401', () async {
    var requests = 0;
    final refreshes = <bool>[];
    final inner = MockClient((request) async {
      requests++;
      expect(request.headers['x-user-id'], isNull);
      expect(request.headers['authorization'], 'Bearer token-$requests');
      return http.Response(
        requests == 1 ? 'expired' : 'ok',
        requests == 1 ? 401 : 200,
      );
    });
    final client = NexusAuthenticatedClient(
      preset: BackendPreset.piWan,
      userId: '7',
      inner: inner,
      authHeaders: (forceRefresh) async {
        refreshes.add(forceRefresh);
        return {'authorization': 'Bearer token-${refreshes.length}'};
      },
    );

    final response = await client.get(Uri.parse('https://nexus.example/test'));

    expect(response.statusCode, 200);
    expect(requests, 2);
    expect(refreshes, [false, true]);
    client.close();
  });
}
