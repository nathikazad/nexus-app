import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/data/background/background_runtime.dart';
import 'package:nexus_voice_assistant/data/ble/bg_ble_client.dart';
import 'package:nexus_voice_assistant/data/socket/bg_socket_client.dart';

class FakeDevice extends BleClient {
  final audio = <List<int>>[];
  final camera = <List<int>>[];
  bool cameraOk = true;
  Completer<void>? audioWrite;
  @override
  Future<bool> initialize() async => true;
  @override
  Future<bool> scanAndConnect({String? overrideRemoteId}) async => true;
  @override
  Future<void> sendAudio(Uint8List data) async {
    audio.add(data.toList());
    await audioWrite?.future;
  }

  @override
  Future<bool> writeCamera(Uint8List data) async {
    camera.add(data.toList());
    return cameraOk;
  }
}

class FakeSocket extends SocketClient {
  final packets = <(int?, List<int>)>[];
  final images = <List<int>>[];
  @override
  bool get isConnected => true;
  @override
  SocketSendStatus sendPacket(Uint8List data, {int? index}) {
    packets.add((index, data.toList()));
    return SocketSendStatus.sent;
  }

  @override
  void sendImagePacket(Uint8List data, int index) {
    images.add(data.toList());
  }
}

class FakeService extends ServiceInstance {
  final events = <(String, Map<String, dynamic>?)>[];
  @override
  void invoke(String method, [Map<String, dynamic>? args]) {
    events.add((method, args));
  }

  @override
  Stream<Map<String, dynamic>?> on(String method) => const Stream.empty();
  @override
  Future<void> stopSelf() async {}
}

void main() {
  late FakeDevice device;
  late FakeSocket socket;
  setUp(() async {
    device = FakeDevice();
    socket = FakeSocket();
    await BackgroundRuntime.start(FakeService(),
        device: device,
        socket: socket,
        initializePlugins: false,
        maintenanceTick: false);
  });
  test(
      'NRF packets and EOF keep monotonic indexes; ACK never blocks next packet',
      () async {
    device.audioWrite = Completer<void>();
    final audio = Uint8List.fromList([1, 0, 0, 0x87, 2, 0, 9, 8]);
    final eof = Uint8List.fromList([0xfc, 0xff, 0, 0x87]);
    device.onAudioPacketReceived!(audio);
    device.onAudioPacketReceived!(eof);
    expect(socket.packets.map((p) => p.$1), [1, 2]);
    expect(socket.packets.map((p) => p.$2), [audio.toList(), eof.toList()]);
    expect(device.audio, [
      [65, 67, 75],
      [65, 67, 75]
    ]);
    device.audioWrite!.complete();
  });
  test(
      'record sets clamped period before start and aborts if period write fails',
      () async {
    expect(
        jsonDecode((await socket.onDeviceRequest!(
            1, 'start_record', {'periodSec': 2000}))!),
        {'success': true});
    expect(device.camera, [
      [4, 0xe8, 3],
      [2]
    ]);
    device.camera.clear();
    device.cameraOk = false;
    expect(jsonDecode((await socket.onDeviceRequest!(2, 'start_record', {}))!),
        {'success': false});
    expect(device.camera, [
      [4, 60, 0]
    ]);
  });
  test(
      'invalid explicit period does not write; capture and power keep their opcodes',
      () async {
    await socket.onDeviceRequest!(1, 'set_record_period', {'periodSec': 0});
    expect(device.camera, isEmpty);
    await socket.onDeviceRequest!(2, 'take_photo', {});
    await socket.onDeviceRequest!(3, 'power_cycle', {});
    expect(device.camera, [
      [1],
      [5]
    ]);
  });
  test(
      'only image file packets go to image socket; downlink bytes go unchanged to device',
      () async {
    device.onFileTxDataReceived!(Uint8List.fromList([0, 1, 0, 1, 65, 0, 9]));
    device.onFileTxDataReceived!(Uint8List.fromList([0, 2, 0, 1, 65, 0, 9]));
    expect(socket.images, [
      [0, 1, 0, 1, 65, 0, 9]
    ]);
    await socket.onPacketFromServer!(Uint8List.fromList([0, 0x87, 1, 0, 9]));
    expect(device.audio, [
      [0, 0x87, 1, 0, 9]
    ]);
  });
}
