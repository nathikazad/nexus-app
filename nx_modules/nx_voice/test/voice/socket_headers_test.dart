import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_voice/src/voice/socket_client.dart';

void main() {
  test(
      'WebSocket sends one domain header with session configuration precedence',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final received = Completer<HttpHeaders>();
    final sockets = <WebSocket>[];
    final subscription = server.listen((request) async {
      received.complete(request.headers);
      sockets.add(await WebSocketTransformer.upgrade(request));
    });
    final client = NxVoiceSocketClient(maxReconnectAttempts: 0);
    addTearDown(() async {
      await client.disconnect();
      for (final socket in sockets) {
        await socket.close();
      }
      await subscription.cancel();
      await server.close(force: true);
    });

    expect(
        await client.connect(
          'ws://127.0.0.1:${server.port}',
          authHeaders: (_) async => {
            'authorization': 'Bearer test-token',
            'x-nexus-domain-id': '1',
          },
          headers: {'X-Nexus-Domain-Id': '2', 'X-Client-App': 'nx_books'},
        ),
        isTrue);
    final headers = await received.future;
    expect(headers['x-nexus-domain-id'], ['2']);
    expect(headers.value('authorization'), 'Bearer test-token');
    expect(headers.value('x-client-app'), 'nx_books');
  });
}
