import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexus_voice_assistant/data/devices/necklace_identity.dart';
import 'package:nexus_voice_assistant/data/devices/necklace_enrollment.dart';

const deviceId = '00112233-4455-6677-8899-aabbccddeeff';
Uint8List identity() => Uint8List.fromList([
      ...identityBytes(deviceId.replaceAll('-', '')),
      4,
      ...List.filled(64, 1),
      1
    ]);
Uint8List proof({bool pending = true}) => Uint8List.fromList([
      4,
      ...List.filled(64, 1),
      ...List.filled(64, 128),
      pending ? 1 : 0,
      if (pending) ...List.filled(32, 2)
    ]);

void main() {
  test('PSA signature encoding matches the server cryptographic vector', () {
    final vector = jsonDecode(
        File('test/data/devices/fixtures/necklace-proof.json')
            .readAsStringSync()) as Map<String, dynamic>;
    expect(
        identityHex(identitySignatureDer(
            identityBytes(vector['raw_signature'] as String))),
        vector['signature']);
  });
  test('provisions UUID and pairing secret without transporting a private key',
      () async {
    final device = NecklaceIdentity((request) async {
      expect(request.length, 49);
      expect(request[0], 2);
      expect(identityUuid(request.sublist(1, 17)), deviceId);
      expect(request.sublist(17), List.filled(32, 2));
      return identity();
    });
    await device.provision({
      'device_type': 'necklace',
      'device_id': deviceId,
      'pairing_secret': '02' * 32
    });
  });
  test(
      'authenticates with device proof, confirms only after success, caches token',
      () async {
    final ops = <int>[];
    final paths = <String>[];
    final auth = NecklaceDeviceAuth(
        baseUrl: 'https://nexus.example',
        deviceId: deviceId,
        isCurrent: () => true,
        exchange: (request) async {
          ops.add(request[0]);
          if (request[0] == 3) {
            expect(request.sublist(1), List.filled(32, 3));
            return proof();
          }
          return identity();
        },
        client: MockClient((request) async {
          expect(request.headers.containsKey('authorization'), false);
          paths.add(request.url.path);
          final body = jsonDecode(request.body);
          expect(body['device_id'], deviceId);
          if (request.url.path.endsWith('challenge'))
            return http.Response(jsonEncode({'nonce': '03' * 32}), 200);
          expect(body['pairing_secret'], '02' * 32);
          expect(body['public_key'], '04${'01' * 64}');
          expect((body['signature'] as String).startsWith('3046022100'), true);
          return http.Response(
              jsonEncode(
                  {'access_token': 'nd1_${'ab' * 32}', 'expires_in': 3600}),
              200);
        }));
    final headers = await auth.headers(false);
    expect(headers, {'authorization': 'Bearer nd1_${'ab' * 32}'});
    expect(await auth.headers(false), headers);
    expect(paths.length, 2);
    expect(ops, [1, 3, 4]);
    auth.close();
    expect(() => auth.headers(false), throwsStateError);
  });
  test('refuses a different connected device before contacting Nexus',
      () async {
    final auth = NecklaceDeviceAuth(
        baseUrl: 'https://nexus.example',
        deviceId: deviceId,
        isCurrent: () => true,
        exchange: (_) async => Uint8List(82),
        client: MockClient((_) async {
          fail('Must not call HTTP');
        }));
    await expectLater(auth.headers(false), throwsStateError);
    auth.close();
  });
  test(
      'revoked or failed proof never confirms enrollment or supplies user auth',
      () async {
    final ops = <int>[];
    final auth = NecklaceDeviceAuth(
        baseUrl: 'https://nexus.example',
        deviceId: deviceId,
        isCurrent: () => true,
        exchange: (r) async {
          ops.add(r[0]);
          return r[0] == 3 ? proof() : identity();
        },
        client: MockClient((r) async => r.url.path.endsWith('challenge')
            ? http.Response(jsonEncode({'nonce': '03' * 32}), 200)
            : http.Response('{}', 403)));
    await expectLater(auth.headers(false), throwsStateError);
    expect(ops, [1, 3]);
    auth.close();
  });
  test('account or BLE change during challenge invalidates the operation',
      () async {
    var current = true;
    final ops = <int>[];
    final auth = NecklaceDeviceAuth(
        baseUrl: 'https://nexus.example',
        deviceId: deviceId,
        isCurrent: () => current,
        exchange: (r) async {
          ops.add(r[0]);
          return identity();
        },
        client: MockClient((r) async {
          current = false;
          return http.Response(jsonEncode({'nonce': '03' * 32}), 200);
        }));
    await expectLater(auth.headers(false), throwsStateError);
    expect(ops, [1]);
    auth.close();
  });
  test('enrollment is bound to backend, owner and BLE peripheral', () async {
    SharedPreferences.setMockInitialValues({});
    await NecklaceEnrollment.save('hosted', '7', 'ble-a', deviceId);
    expect(await NecklaceEnrollment.load('hosted', '7', 'ble-a'), deviceId);
    expect(await NecklaceEnrollment.load('hosted', '8', 'ble-a'), isNull);
    expect(await NecklaceEnrollment.load('direct', '7', 'ble-a'), isNull);
    expect(await NecklaceEnrollment.load('hosted', '7', 'ble-b'), isNull);
  });
}
