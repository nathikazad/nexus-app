import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/data/socket/bg_socket_client.dart';

void main() {
  test('SocketClient queues binary packets when disconnected', () {
    final client = SocketClient();
    expect(client.isConnected, isFalse);
    expect(client.connectionState, SocketConnectionState.disconnected);
    expect(client.queuedPacketCount, 0);

    final status = client.sendPacket(Uint8List.fromList([1, 2, 3]), index: 1);
    expect(status, SocketSendStatus.queuedNoConnection);
    expect(client.queuedPacketCount, 1);
  });

  test('ensureConnected does not retry without a configured URL', () async {
    final client = SocketClient();

    final connected = await client.ensureConnected(reason: 'test');

    expect(connected, isFalse);
    expect(client.connectionState, SocketConnectionState.disconnected);
  });
}
