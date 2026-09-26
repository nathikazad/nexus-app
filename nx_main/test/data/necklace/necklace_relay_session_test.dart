import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/data/necklace/necklace_relay.dart';
import 'package:nexus_voice_assistant/data/necklace/necklace_device_port.dart';
import 'package:nexus_voice_assistant/data/socket/bg_socket_client.dart';
import '../background/necklace_behavior_contract_test.dart' show FakeDevice;

class ReconnectingSocket extends SocketClient {
  final connecting = Completer<bool>();
  int clears = 0;
  int connects = 0;
  @override
  Future<bool> ensureConnected({String reason = 'ensureConnected'}) {
    connects++;
    return connecting.future;
  }

  @override
  void clearQueue() {
    clears++;
  }
}

void main() {
  test('retired reconnect failure cannot clear a newer session queue',
      () async {
    final socket = ReconnectingSocket();
    var generation = 1;
    final relay = NecklaceRelay(
        device: BleNecklaceDevicePort(FakeDevice()),
        socketClient: socket,
        emit: (_, __) {},
        currentGeneration: () => generation);
    relay.onAudioPacket(Uint8List.fromList([1, 0, 0, 0x87, 1, 0, 9]));
    generation++;
    socket.connecting.complete(false);
    await Future<void>.delayed(Duration.zero);
    expect(socket.clears, 0);
  });
  test(
      'one reconnect attempt per turn and failed current connection drops queue',
      () async {
    final socket = ReconnectingSocket();
    final relay = NecklaceRelay(
        device: BleNecklaceDevicePort(FakeDevice()),
        socketClient: socket,
        emit: (_, __) {},
        currentGeneration: () => 1);
    relay.onAudioPacket(Uint8List.fromList([1, 0, 0, 0x87, 1, 0, 9]));
    relay.onAudioPacket(Uint8List.fromList([0xfc, 0xff, 0, 0x87]));
    expect(socket.connects, 1);
    socket.connecting.complete(false);
    await Future<void>.delayed(Duration.zero);
    expect(socket.clears, 1);
  });
}
