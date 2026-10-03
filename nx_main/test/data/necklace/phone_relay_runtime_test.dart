import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/data/file_transfer/protocol.dart';
import 'package:nexus_voice_assistant/data/necklace/necklace_device_port.dart';
import 'package:nexus_voice_assistant/data/necklace/phone_relay_runtime.dart';
import 'package:nexus_voice_assistant/data/socket/bg_socket_client.dart';

class Device
    implements NecklaceDevicePort, NecklaceAudioControlPort, NecklaceFilePort {
  final files = <Uint8List>[], audio = <Uint8List>[], camera = <Uint8List>[];
  bool writable = true;
  @override
  Future<bool> writeFileRx(Uint8List b) async {
    if (writable) files.add(b);
    return writable;
  }

  @override
  Future<void> sendAudio(Uint8List b) async {
    audio.add(b);
  }

  @override
  Future<bool> writeCamera(Uint8List b) async {
    camera.add(b);
    return true;
  }

  @override
  Future<bool> writeBackgroundAudio(int op, {Uint8List? fileId}) async => true;
  @override
  Future<(bool, int)?> readCameraStatus() async => (false, 60);
  @override
  Future<Uint8List?> readBattery() async => null;
  @override
  Future<bool> writeHaptic(int id) async => true;
}

class Socket extends SocketClient {
  final files = <Uint8List>[];
  Map<String, String>? metadata;
  bool connected = false, sending = true;
  int retries = 0;
  Completer<bool>? delayConnect;
  @override
  bool get isConnected => connected;
  @override
  Future<bool> connect(String url,
      {Map<String, String>? headers,
      Future<Map<String, String>> Function(bool)? authHeaders}) async {
    expect(authHeaders, isNotNull,
        reason: 'Both hosts must use device authentication');
    metadata = headers;
    final delay = delayConnect;
    delayConnect = null;
    if (delay != null) return delay.future;
    connected = true;
    return true;
  }

  @override
  Future<void> disconnect({bool clearQueuedPackets = true}) async {
    connected = false;
  }

  @override
  bool sendFilePacket(Uint8List b) {
    if (connected && sending) {
      files.add(b);
      return true;
    }
    return false;
  }

  @override
  Future<bool> ensureConnected({String reason = 'ensureConnected'}) async {
    retries++;
    return connected;
  }
}

PhoneRelaySession session({int domain = 2, bool Function()? current}) =>
    PhoneRelaySession(
        httpUrl: 'http://localhost',
        socketUrl: 'ws://localhost',
        deviceId: 'device',
        domainId: domain,
        exchangeIdentity: (_) async =>
            throw StateError('Fake socket must not authenticate'),
        isCurrent: current ?? () => true);
void main() {
  late Device device;
  late Socket socket;
  late PhoneRelayRuntime runtime;
  final manifest =
      FileManifest('12' * 16, FileKind.photo, 'photo.jpg', 3, crc32([1, 2, 3]));
  setUp(() {
    device = Device();
    socket = Socket();
    runtime = PhoneRelayRuntime(device: device, socket: socket);
  });
  tearDown(() => runtime.close());
  test(
      'shared connection authenticates, negotiates and relays without synthesizing ACKs',
      () async {
    expect(await runtime.connect(session()), true);
    expect(socket.metadata, {'X-Client-Id': 'necklace', 'X-Domain-Id': '2'});
    expect(device.files.single, fileHello);
    runtime.onNotification('file', manifest.begin());
    expect(socket.files.single, manifest.begin());
    expect(device.files.length, 1);
    await socket.onFilePacket!(manifest.control(FileOp.commit, 3));
    expect(device.files.last, manifest.control(FileOp.commit, 3));
    await runtime.execute(1, 'take_photo', {'file_id': manifest.id});
    expect(device.camera.single, [1, ...List.filled(16, 0x12)]);
  });
  test('file retry reconnects; offline bytes are never queued or acknowledged',
      () async {
    await runtime.connect(session());
    socket.sending = false;
    runtime.onNotification('file', manifest.begin());
    await runtime.drained;
    expect(socket.retries, 1);
    expect(socket.files, isEmpty);
    expect(device.files.length, 1);
    socket.sending = true;
    expect(socket.files, isEmpty);
    runtime.onNotification('file', manifest.begin());
    expect(socket.files.length, 1);
  });
  test('old file/audio/command callbacks cannot reach a replacement session',
      () async {
    await runtime.connect(session());
    final oldFile = socket.onFilePacket!,
        oldAudio = socket.onPacketFromServer!,
        oldCommand = socket.onDeviceRequest!;
    await runtime.connect(session(domain: 3));
    final count = device.files.length;
    await oldFile(manifest.control(FileOp.commit, 3));
    await oldAudio(Uint8List.fromList([1, 2]));
    expect(
        jsonDecode((await oldCommand(1, 'take_photo', {}))!)['success'], false);
    expect(device.files.length, count);
    expect(device.audio, isEmpty);
    expect(device.camera, isEmpty);
    expect(socket.metadata!['X-Domain-Id'], '3');
  });
  test('late connect cannot negotiate or disconnect newer session', () async {
    final delayed = Completer<bool>();
    socket.delayConnect = delayed;
    final first = runtime.connect(session());
    await Future<void>.delayed(Duration.zero);
    expect(await runtime.connect(session(domain: 3)), true);
    delayed.complete(true);
    expect(await first, false);
    expect(device.files.length, 1);
    expect(socket.connected, true);
  });
  test('changed identity fails closed even before host disconnect notification',
      () async {
    var current = true;
    await runtime.connect(session(current: () => current));
    current = false;
    await socket.onPacketFromServer!(Uint8List.fromList([1, 2]));
    runtime.onNotification('file', manifest.begin());
    runtime.onNotification('audio', Uint8List.fromList([1, 2]));
    await socket.onFilePacket!(manifest.control(FileOp.commit, 3));
    expect(jsonDecode((await runtime.execute(1, 'take_photo', {}))!)['success'],
        false);
    expect(socket.files, isEmpty);
    expect(device.audio, isEmpty);
    expect(device.camera, isEmpty);
    expect(device.files.length, 1);
  });
  test('failed negotiation retires the session', () async {
    device.writable = false;
    await expectLater(runtime.connect(session()), throwsStateError);
    expect(socket.connected, false);
    expect(socket.onFilePacket, isNull);
    expect(jsonDecode((await runtime.execute(1, 'take_photo', {}))!)['success'],
        false);
  });
  test('legacy and malformed file frames cannot bypass the receiver', () async {
    await runtime.connect(session());
    runtime.onNotification('file', Uint8List.fromList([0, 1, 0, 1, 0, 5]));
    runtime.onNotification('file', Uint8List.fromList([0, 0x84, 2, 1]));
    expect(socket.files, isEmpty);
    expect(device.files.length, 1);
  });
}
