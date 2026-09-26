import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/data/socket/bg_socket_client.dart';

// Golden bytes are intentionally independent of the production encoder.
// Changing these requires a matching server/firmware protocol change.
void main() {
  late HttpServer server;
  late SocketClient client;
  late StreamIterator<List<int>> received;
  late Completer<WebSocket> peer;
  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    client = SocketClient();
    peer = Completer<WebSocket>();
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      received =
          StreamIterator(socket.map((value) => List<int>.from(value as List)));
      peer.complete(socket);
    });
  });
  tearDown(() async {
    await client.disconnect();
    if (peer.isCompleted) {
      await received.cancel();
      await (await peer.future).close();
    }
    await server.close(force: true);
  });
  Future<void> connect() async {
    expect(
        await client.connect('ws://127.0.0.1:${server.port}',
            headers: {'X-Nexus-Domain-Id': '7'}),
        isTrue);
    await peer.future;
  }

  Future<void> packet(List<int> golden) async {
    expect(
        await received.moveNext().timeout(const Duration(seconds: 2)), isTrue);
    expect(received.current, golden);
  }

  test('uplink preserves NRF meta and EOF, text UTF8 and image bytes',
      () async {
    await connect();
    client.sendPacket(Uint8List.fromList([1, 0, 0x23, 0x87, 2, 0, 9, 8]),
        index: 0x102);
    await packet([1, 0, 2, 1, 0, 0, 1, 0, 0x23, 0x87, 2, 0, 9, 8]);
    client.sendPacket(Uint8List.fromList([0xfc, 0xff, 0x23, 0x87]),
        index: 0x103);
    await packet([1, 0, 3, 1, 0, 0, 0xfc, 0xff, 0x23, 0x87]);
    client.sendTextPacket('é', 3);
    await packet([2, 0, 3, 0, 0, 0, 2, 0, 0xc3, 0xa9]);
    client.sendImagePacket(Uint8List.fromList([0, 1, 0, 1, 65, 0, 9]), 4);
    await packet([3, 0, 4, 0, 0, 0, 7, 0, 0, 1, 0, 1, 65, 0, 9]);
    client.sendTextEofPacket(5);
    await packet([6, 0, 5, 0, 0, 0]);
    client.sendAudioEofPacket(6);
    await packet([0xfc, 0xff, 6, 0, 0, 0]);
  });
  test('auth wait copies and flushes queued audio and images in FIFO order',
      () async {
    final auth = Completer<Map<String, String>>();
    final connecting = client.connect('ws://127.0.0.1:${server.port}',
        headers: {'X-Nexus-Domain-Id': '7'}, authHeaders: (_) => auth.future);
    await Future<void>.delayed(Duration.zero);
    final source = Uint8List.fromList([7, 8]);
    client.sendPacket(source, index: 1);
    source[0] = 99;
    client.sendImagePacket(Uint8List.fromList([9]), 2);
    expect(client.queuedPacketCount, 2);
    auth.complete({});
    expect(await connecting, isTrue);
    await peer.future;
    await packet([1, 0, 1, 0, 0, 0, 7, 8]);
    await packet([3, 0, 2, 0, 0, 0, 1, 0, 9]);
    expect(client.queuedPacketCount, 0);
  });
  test('device response retains request id and index zero', () async {
    await connect();
    client.sendDeviceResponsePacket(0x102, '{}');
    await packet([5, 0, 0, 0, 0, 0, 2, 1, 0, 0, 2, 0, 123, 125]);
  });
  test('logout suppresses a device response still awaiting hardware', () async {
    await connect();
    final entered = Completer<void>();
    final result = Completer<String?>();
    client.onDeviceRequest = (_, __, ___) {
      entered.complete();
      return result.future;
    };
    final body = utf8.encode('{"action":"get_battery"}');
    (await peer.future)
        .add([0, 0, 0, 0, 4, 0, 12, 0, 0, 0, body.length, 0, ...body]);
    await entered.future.timeout(const Duration(seconds: 2));
    await client.disconnect();
    result.complete('{"percent":87}');
    expect(
        await received.moveNext().timeout(const Duration(seconds: 2)), isFalse);
    expect(client.queuedPacketCount, 0);
  });
}
