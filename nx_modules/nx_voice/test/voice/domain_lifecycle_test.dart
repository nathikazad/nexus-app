import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_voice/nx_voice.dart';

void main() {
  test('closing a session cancels a connection awaiting credentials', () async {
    final credentials = Completer<Map<String, String>>();
    final socket = NxVoiceSocketClient();
    final pending = socket.connect('ws://127.0.0.1:1',
        headers: {'X-Nexus-Domain-Id': '2'},
        authHeaders: (_) => credentials.future);
    await socket.disconnect();
    credentials.complete({'authorization': 'Bearer old-session'});
    expect(await pending, isFalse);
    expect(socket.isConnected, isFalse);
    expect(socket.queuedPacketCount, 0);
  });

  test(
      'voice identity includes the selected domain and preserves it for passages',
      () {
    Future<Map<String, String>> auth(bool _) async => {};
    final personal = DocumentAiSessionConfig(
        socketUrl: 'ws://localhost',
        userId: '7',
        domainId: 1,
        documentId: 12,
        authHeaders: auth);
    final shared = DocumentAiSessionConfig(
        socketUrl: 'ws://localhost',
        userId: '7',
        domainId: 2,
        documentId: 12,
        authHeaders: auth);
    expect(personal.key, isNot(shared.key));
    expect(shared.withSelection('A passage').headers['X-Nexus-Domain-Id'], '2');
  });
}
