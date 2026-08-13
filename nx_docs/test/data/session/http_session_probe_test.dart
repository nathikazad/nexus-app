import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_docs/application/ports/session_store.dart';
import 'package:nx_docs/application/session/offline_session_restorer.dart';
import 'package:nx_docs/data/session/http_session_probe.dart';

void main() {
  const session = CachedSession(userId: '1', backendPreset: 'localhost');

  test('successful response classifies the session as available', () async {
    final probe = HttpSessionProbe(
      client: MockClient((request) async {
        expect(request.headers['x-user-id'], '1');
        return http.Response('{"data":{"__typename":"Query"}}', 200);
      }),
    );

    expect(await probe(session), SessionProbeResult.available);
  });

  test('authorization status requires login', () async {
    final probe = HttpSessionProbe(
      client: MockClient((_) async => http.Response('denied', 401)),
    );

    expect(await probe(session), SessionProbeResult.unauthorized);
  });

  test('transport error is offline and does not imply rejection', () async {
    final probe = HttpSessionProbe(
      client: MockClient((_) async => throw Exception('network down')),
    );

    expect(await probe(session), SessionProbeResult.unreachable);
  });
}
