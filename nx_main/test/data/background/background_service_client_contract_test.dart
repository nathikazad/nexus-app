import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/data/background/background_service_client.dart';

class ServiceBus implements FlutterBackgroundService {
  final streams = <String, StreamController<Map<String, dynamic>?>>{};
  void Function(Map<String, dynamic>)? command;
  @override
  Stream<Map<String, dynamic>?> on(String method) =>
      (streams[method] ??= StreamController.broadcast(sync: true)).stream;
  @override
  void invoke(String method, [Map<String, dynamic>? args]) {
    if (method == 'ble.command') command!(args!);
  }

  void reply(Map<String, dynamic> result) =>
      streams['ble.command.result']!.add(result);
  @override
  Future<bool> startService() async => true;
  @override
  Future<bool> isRunning() async => true;
  @override
  Future<bool> configure(
          {required IosConfiguration iosConfiguration,
          required AndroidConfiguration androidConfiguration}) async =>
      true;
  Future<void> close() async {
    for (final stream in streams.values) {
      await stream.close();
    }
  }
}

void main() {
  late ServiceBus bus;
  late BackgroundServiceClient client;
  setUp(() async {
    bus = ServiceBus();
    client = BackgroundServiceClient(service: bus);
    await client.start();
  });
  tearDown(() async {
    client.dispose();
    await bus.close();
  });
  test('synchronous reply is correlated after request is registered', () async {
    bus.command = (request) {
      expect(request, {
        'command': 'writeCamera',
        'requestId': 1,
        'data': {
          'data': [1]
        }
      });
      bus.reply({'command': 'writeCamera', 'requestId': 99, 'success': false});
      bus.reply({'command': 'writeCamera', 'requestId': 1, 'success': true});
    };
    expect(await client.writeCamera(Uint8List.fromList([1])), isTrue);
  });
  test('reply for the wrong command cannot confirm an operation', () async {
    bus.command = (request) => bus.reply({
          'command': 'writeHaptic',
          'requestId': request['requestId'],
          'success': true
        });
    expect(await client.writeCamera(Uint8List.fromList([1])), isFalse);
  });
  test('camera state bytes preserve little endian period interpretation',
      () async {
    bus.command = (request) => bus.reply({
          'command': 'readCameraStatus',
          'requestId': request['requestId'],
          'success': true,
          'data': [1, 0xe8, 3]
        });
    expect(await client.readCameraStatus(), (true, 1000));
  });
}
