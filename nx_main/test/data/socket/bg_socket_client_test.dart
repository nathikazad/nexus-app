import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/data/socket/bg_socket_client.dart';

void main() {
  test('SocketClient queues binary packets when disconnected', () {
    final client = SocketClient();
    expect(client.isConnected, isFalse);
    expect(client.queuedPacketCount, 0);

    client.sendPacket(Uint8List.fromList([1, 2, 3]), index: 1);
    expect(client.queuedPacketCount, 1);
  });
}
