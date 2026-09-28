import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nx_db/auth.dart';
import 'package:nexus_voice_assistant/data/background/background_runtime.dart';
import 'package:nexus_voice_assistant/data/background/background_session_command.dart';
import 'package:nexus_voice_assistant/data/ble/bg_ble_client.dart';
import 'package:nexus_voice_assistant/data/devices/necklace_identity.dart';
import 'package:nexus_voice_assistant/data/devices/necklace_enrollment.dart';
import 'package:nexus_voice_assistant/data/socket/bg_socket_client.dart';
import 'package:nexus_voice_assistant/domain/ble/ble_connection_state.dart';

const id = '00112233-4455-6677-8899-aabbccddeeff';

class Device extends BleClient {
  bool connected = true;
  @override
  bool get isConnected => connected;
  @override
  BluetoothDevice get device => BluetoothDevice.fromId('ble-a');
  @override
  Future<bool> initialize() async => true;
  @override
  Future<Uint8List> exchangeIdentity(Uint8List r) async {
    if (r[0] == 3) return Uint8List.fromList([4, ...List.filled(128, 1), 0]);
    return Uint8List.fromList([
      ...identityBytes(id.replaceAll('-', '')),
      4,
      ...List.filled(64, 1),
      0
    ]);
  }
}

class Socket extends SocketClient {
  final connections = <Map<String, String>>[];
  int disconnects = 0;
  @override
  Future<bool> connect(String url,
      {Map<String, String>? headers,
      Future<Map<String, String>> Function(bool)? authHeaders}) async {
    connections.add({...?headers, ...?await authHeaders?.call(false)});
    return true;
  }

  @override
  Future<void> disconnect({bool clearQueuedPackets = true}) async {
    disconnects++;
  }
}

class Service extends ServiceInstance {
  final channels = <String, StreamController<Map<String, dynamic>?>>{};
  final outputs = <(String, Map<String, dynamic>?)>[];
  @override
  Stream<Map<String, dynamic>?> on(String method) =>
      (channels[method] ??= StreamController.broadcast()).stream;
  @override
  void invoke(String method, [Map<String, dynamic>? args]) {
    outputs.add((method, args));
  }

  @override
  Future<void> stopSelf() async {}
  void send(String method, [Map<String, dynamic>? args]) {
    channels[method]!.add(args);
  }

  Future<void> close() async {
    for (final c in channels.values) {
      await c.close();
    }
  }
}

Future<void> until(bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(ready(), true);
}

void main() {
  test(
      'relay waits for enrollment, uses device bearer, and retires on BLE loss',
      () async {
    SharedPreferences.setMockInitialValues({});
    final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final base = 'http://127.0.0.1:${http.port}';
    final requests = <String>[];
    http.listen((request) async {
      requests.add(request.uri.path);
      if (request.uri.path.endsWith('challenge')) {
        expect(request.headers.value('authorization'), isNull);
        request.response.write(jsonEncode({'nonce': '03' * 32}));
      } else if (request.uri.path.endsWith('token')) {
        final proof = jsonDecode(await utf8.decoder.bind(request).join());
        expect(proof['device_id'], id);
        request.response.write(jsonEncode(
            {'access_token': 'nd1_${'ab' * 32}', 'expires_in': 3600}));
      } else {
        // Phone telemetry being unavailable must not prevent the device socket.
        request.response.statusCode = 503;
        request.response.write('{}');
      }
      await request.response.close();
    });
    final device = Device(), socket = Socket(), service = Service();
    await BackgroundRuntime.start(service,
        device: device,
        socket: socket,
        initializePlugins: false,
        maintenanceTick: false);
    final config = BackgroundSessionCommand(
        url: 'ws://127.0.0.1:12345',
        telemetryHttpBaseUrl: base,
        userId: '7',
        preset: BackendPreset.localhost,
        clientAppId: 'nx_main');
    service.send('socket.connect', config.toMap());
    await until(() => service.outputs.any((e) => e.$1 == 'ble.error'));
    expect(socket.connections, isEmpty);
    expect(requests, isEmpty);
    await NecklaceEnrollment.save(
        BackendPreset.localhost.key, '7', 'ble-a', id);
    service.send('device.enrolled');
    await until(() => socket.connections.isNotEmpty);
    expect(socket.connections.single, {
      'X-Client-Id': 'necklace',
      'X-Nexus-Session-Mode': 'ambient',
      'authorization': 'Bearer nd1_${'ab' * 32}',
    });
    await until(() => requests.contains('/v1/domains'));
    final before = socket.disconnects;
    device.connected = false;
    device.onConnectionStateChanged!(BleConnectionState.idle);
    await until(() => socket.disconnects > before);
    service.send('socket.disconnect');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await service.close();
    await http.close(force: true);
  });
}
