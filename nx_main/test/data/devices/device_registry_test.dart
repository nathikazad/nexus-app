import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_db/auth.dart';
import 'package:nexus_voice_assistant/data/devices/device_registry.dart';

void main() {
  test('pairing is authenticated but independent of selected domain', () async {
    final client = DeviceRegistry(
        User(userId: '42', preset: BackendPreset.hosted, domainId: 91),
        headers: (_) async => {'authorization': 'Bearer user-access'},
        client: MockClient((request) async {
          expect(request.url.path, '/v1/devices');
          expect(request.headers['authorization'], 'Bearer user-access');
          expect(request.headers.containsKey('x-nexus-domain-id'), false);
          expect(jsonDecode(request.body), {'device_type': 'sleepbot_radar'});
          return http.Response(
              '{"device_id":"id","pairing_secret":"secret"}', 200);
        }));
    expect((await client.pair('sleepbot_radar'))['device_id'], 'id');
    client.close();
  });
  test('refreshes expired user token once and never retries forbidden response',
      () async {
    var calls = 0;
    final refresh = <bool>[];
    final client =
        DeviceRegistry(User(userId: '42', preset: BackendPreset.hosted),
            headers: (force) async {
      refresh.add(force);
      return {'authorization': 'Bearer token'};
    }, client: MockClient((request) async {
      calls++;
      return http.Response(
          calls == 1 ? '{}' : '{"devices":[]}', calls == 1 ? 401 : 200);
    }));
    expect(await client.list(), isEmpty);
    expect(refresh, [false, true]);
    client.close();
    await expectLater(client.list(), throwsStateError);
  });
}
