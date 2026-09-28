import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_voice/nx_voice.dart';

void main() {
  test('optional scope headers and context travel separately on one socket',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final received = <Object>[];
    final headers = Completer<HttpHeaders>();
    final complete = Completer<void>();
    WebSocket? ws;
    final subscription = server.listen((request) async {
      headers.complete(request.headers);
      ws = await WebSocketTransformer.upgrade(request);
      ws!.listen((frame) {
        received.add(frame as Object);
        if (received.length == 7) complete.complete();
      });
    });
    final session = DocumentAiSession();
    addTearDown(() async {
      await session.disconnect();
      await ws?.close();
      await subscription.cancel();
      await server.close(force: true);
    });
    await session.connect(DocumentAiSessionConfig(
      socketUrl: 'ws://127.0.0.1:${server.port}',
      userId: '1',
      clientId: 'nx_books',
      transcriptId: 42,
      authHeaders: (_) async => {'X-User-Id': '1'},
    ));
    session.sendTextTurn('question', context: 'page one');
    session.sendTextTurn('next');
    session.beginAudioTurn(context: 'page two');
    await complete.future.timeout(const Duration(seconds: 5));
    final h = await headers.future;
    expect(h.value('x-transcript-id'), '42');
    expect(h.value('x-domain-id'), isNull);
    expect(h.value('x-document-id'), isNull);
    expect(h.value('x-agent-id'), isNull);
    expect(h.value('x-reading-selection'), isNull);
    expect(jsonDecode(received[0] as String),
        {'type': 'input_context', 'input': 'text', 'context': 'page one'});
    expect(jsonDecode(received[3] as String)['context'], '');
    expect(jsonDecode(received[6] as String),
        {'type': 'input_context', 'input': 'audio', 'context': 'page two'});
  });
}
