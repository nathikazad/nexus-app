import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_auth/nx_auth.dart';

void main() {
  test('direct transport replaces a caller-supplied user identity', () async {
    late http.Request received;
    final client = NexusAuthenticatedClient(
      preset: BackendPreset.piTailscale,
      userId: '7',
      inner: MockClient((request) async {
        received = request;
        return http.Response('ok', 200);
      }),
    );

    await client.get(
      Uri.parse('http://100.108.43.37/test'),
      headers: {'x-user-id': '999'},
    );

    expect(received.headers['x-user-id'], '7');
    client.close();
  });

  test('hosted transport refreshes and retries once after a 401', () async {
    var requests = 0;
    final refreshes = <bool>[];
    final client = NexusAuthenticatedClient(
      preset: BackendPreset.piWan,
      userId: '7',
      inner: MockClient((request) async {
        requests++;
        expect(request.headers['authorization'], 'Bearer token-$requests');
        return http.Response('response', requests == 1 ? 401 : 200);
      }),
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
