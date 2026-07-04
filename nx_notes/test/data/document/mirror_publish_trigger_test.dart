import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_notes/data/document/mirror_publish_trigger.dart';

void main() {
  test('posts mirror publish trigger payload', () async {
    late http.Request seen;
    final service = MirrorPublishTriggerService(
      baseUrl: 'http://100.108.43.37:8001',
      userId: '7',
      client: MockClient((request) async {
        seen = request;
        return http.Response('{"ok":true}', 200);
      }),
    );

    await service.trigger(
      reason: 'publish_click',
      documentId: 3245,
      immediate: true,
    );

    expect(seen.method, 'POST');
    expect(
      seen.url.toString(),
      'http://100.108.43.37:8001/mirror/publish/trigger',
    );
    expect(seen.headers['X-User-Id'], '7');
    expect(jsonDecode(seen.body), {
      'reason': 'publish_click',
      'document_id': 3245,
      'immediate': true,
    });
  });

  test('throws on rejected trigger', () async {
    final service = MirrorPublishTriggerService(
      baseUrl: 'http://127.0.0.1:8001',
      userId: '1',
      client: MockClient((request) async => http.Response('disabled', 503)),
    );

    await expectLater(
      service.trigger(reason: 'edit', documentId: 1, immediate: false),
      throwsStateError,
    );
  });
}
