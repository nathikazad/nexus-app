import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/data/socket/bg_socket_client.dart';
import 'package:nexus_voice_assistant/data/voice/voice_socket_session.dart';
import 'package:nexus_voice_assistant/application/sessions/agent_routes.dart';

void main() {
  test('wearable rejects absent domain before opening any connection',
      () async {
    final client = SocketClient();
    await expectLater(client.connect('ws://127.0.0.1:1'), throwsStateError);
    expect(await client.ensureConnected(), isFalse);
  });

  test('logout cancels pending auth and discards queued audio', () async {
    final auth = Completer<Map<String, String>>();
    final client = SocketClient();
    final connecting = client.connect('ws://127.0.0.1:1',
        headers: {'X-Nexus-Domain-Id': '7'}, authHeaders: (_) => auth.future);
    await Future<void>.delayed(Duration.zero);
    client.sendPacket(Uint8List.fromList([1, 2]));
    expect(client.queuedPacketCount, 1);
    await client.disconnect();
    auth.complete({'x-user-id': '1'});
    expect(await connecting, isFalse);
    expect(client.queuedPacketCount, 0);
    expect(await client.ensureConnected(), isFalse);
  });

  test('wearable and phone voice send selected domains on same backend',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final domains = <String?>[];
    final agents = <String?>[];
    final sources = <String?>[];
    final sockets = <WebSocket>[];
    server.listen((request) async {
      domains.add(request.headers.value('x-nexus-domain-id'));
      agents.add(request.headers.value('x-agent-id'));
      sources.add(request.headers.value('x-client-id'));
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((_) {});
    });
    final url = 'ws://127.0.0.1:${server.port}';
    final wearable = SocketClient();
    final voice = VoiceSocketSession();
    addTearDown(() async {
      await wearable.disconnect();
      await voice.disconnect();
      for (final socket in sockets) {
        await socket.close();
      }
      await server.close(force: true);
    });
    expect(await wearable.connect(url, headers: {'X-Nexus-Domain-Id': '7'}),
        isTrue);
    expect(await wearable.connect(url, headers: {'X-Nexus-Domain-Id': '9'}),
        isTrue);
    for (final domain in [7, 9]) {
      await voice.connect(VoiceSocketSessionConfig(
          socketUrl: url,
          userId: '1',
          domainId: domain,
          clientId: 'nx_main',
          authHeaders: (_) async => {}));
    }
    await voice.connect(VoiceSocketSessionConfig(
      socketUrl: url,
      userId: '1',
      domainId: 9,
      clientId: 'nx_watch',
      authHeaders: (_) async => {},
    ));
    expect(
        await wearable.connect(url,
            headers: AgentRoutes.necklace.ambientHeaders()),
        isTrue);
    expect(domains, ['7', '9', '7', '9', '9', null]);
    expect(agents, [
      null,
      null,
      'nx_main',
      'nx_main',
      'personal_assistant',
      'personal_assistant'
    ]);
    expect(sources, [null, null, 'nx_main', 'nx_main', 'nx_watch', 'necklace']);
  });
}
