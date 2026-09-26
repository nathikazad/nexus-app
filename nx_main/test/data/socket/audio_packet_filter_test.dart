import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/data/socket/bg_socket_client.dart';

Uint8List textPacket(String text) {
  final bytes = utf8.encode(text);
  final packet = Uint8List(8 + bytes.length);
  final data = ByteData.sublistView(packet);
  data.setUint16(0, 2, Endian.little);
  data.setUint32(2, 1, Endian.little);
  data.setUint16(6, bytes.length, Endian.little);
  packet.setRange(8, packet.length, bytes);
  return packet;
}

Uint8List deviceRequest(String action) {
  final bytes = utf8.encode(jsonEncode({'action': action}));
  final packet = Uint8List(12 + bytes.length);
  final data = ByteData.sublistView(packet);
  data.setUint32(0, 1, Endian.little);
  data.setUint16(4, 4, Endian.little);
  data.setUint32(6, 7, Endian.little);
  data.setUint16(10, bytes.length, Endian.little);
  packet.setRange(12, packet.length, bytes);
  return packet;
}

Uint8List audioPacket(int meta, List<int> opus) {
  final packet = Uint8List(12 + opus.length);
  final data = ByteData.sublistView(packet);
  data.setUint16(0, 1, Endian.little);
  data.setUint32(2, 1, Endian.little);
  data.setUint16(8, meta, Endian.little);
  data.setUint16(10, opus.length, Endian.little);
  packet.setRange(12, packet.length, opus);
  return packet;
}

void main() {
  test('battery progress and control packets never enter BLE audio', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final peer = Completer<WebSocket>();
    final response = Completer<Uint8List>();
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      socket.listen((packet) {
        if (!response.isCompleted)
          response.complete(Uint8List.fromList(packet as List<int>));
      });
      peer.complete(socket);
    });
    final client = SocketClient();
    final forwarded = <List<int>>[];
    final finished = Completer<void>();
    client.onPacketFromServer = (packet) async {
      forwarded.add(packet.toList());
      if (packet.length >= 2 &&
          packet[0] == 0xfc &&
          packet[1] == 0xff &&
          !finished.isCompleted) finished.complete();
    };
    client.onDeviceRequest = (_, action, __) async =>
        action == 'get_battery' ? '{"success":true,"percent":87}' : null;
    addTearDown(() async {
      await client.disconnect();
      if (peer.isCompleted) await (await peer.future).close();
      await server.close(force: true);
    });
    await client.connect('ws://127.0.0.1:${server.port}',
        headers: {'X-Nexus-Domain-Id': '1'});
    final socket = await peer.future;
    socket.add(deviceRequest('get_battery'));
    final reply = await response.future.timeout(const Duration(seconds: 3));
    expect(ByteData.sublistView(reply).getUint16(0, Endian.little), 5);
    expect(utf8.decode(reply.sublist(12)), contains('87'));
    socket.add(textPacket(
        '{"type":"transcript_delta","text":"Reading battery from your device..."}'));
    socket.add(deviceRequest('unsupported_action'));
    socket.add(Uint8List.fromList([1, 0, 0, 0, 4, 0]));
    socket.add(Uint8List.fromList([1]));
    socket.add(audioPacket(0x6600, []).sublist(0, 10));
    socket.add(audioPacket(0x6600, []));
    final truncated = audioPacket(0x6600, [1]);
    ByteData.sublistView(truncated).setUint16(10, 8, Endian.little);
    socket.add(truncated);
    socket.add(audioPacket(0x6600, [0x98, 0x11]));
    socket.add(
        textPacket('{"type":"transcript","text":"Battery is 87 percent."}'));
    socket.add(Uint8List.fromList([6, 0, 1, 0, 0, 0]));
    socket.add(audioPacket(0x6601, [0x98, 0x22]));
    socket.add(Uint8List.fromList([0xfc, 0xff, 1, 0, 0, 0]));
    await finished.future.timeout(const Duration(seconds: 3));
    expect(forwarded, [
      [0, 0x66, 2, 0, 0x98, 0x11],
      [1, 0x66, 2, 0, 0x98, 0x22],
      [0xfc, 0xff, 0, 0x66]
    ]);
  });
}
