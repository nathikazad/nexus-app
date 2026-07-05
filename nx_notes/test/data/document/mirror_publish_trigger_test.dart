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

  test('attaches Cloudflare Access headers for WAN trigger routes', () async {
    late http.Request seen;
    final service = MirrorPublishTriggerService(
      baseUrl: 'https://nexus.nathikazad.com',
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

    expect(
      seen.url.toString(),
      'https://nexus.nathikazad.com/mirror/publish/trigger',
    );
    expect(seen.headers['CF-Access-Client-Id'], isNotEmpty);
    expect(seen.headers['CF-Access-Client-Secret'], isNotEmpty);
  });

  test('waits for mirror publish status to finish', () async {
    final requests = <String>[];
    final service = MirrorPublishTriggerService(
      baseUrl: 'http://127.0.0.1:8001',
      userId: '1',
      client: MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        if (request.url.path.endsWith('/trigger')) {
          return http.Response('{"ok":true}', 200);
        }
        if (requests
                .where((item) => item == 'GET /mirror/publish/status')
                .length ==
            1) {
          return http.Response(
            '{"ok":true,"status":"running","running":true,"pending_reason":null}',
            200,
          );
        }
        return http.Response(
          '{"ok":true,"status":"succeeded","running":false,"pending_reason":null}',
          200,
        );
      }),
    );

    await service.trigger(
      reason: 'publish_click',
      documentId: 3245,
      immediate: true,
      waitForCompletion: true,
    );

    expect(requests, [
      'POST /mirror/publish/trigger',
      'GET /mirror/publish/status',
      'GET /mirror/publish/status',
    ]);
  });

  test('throws when mirror publish status fails', () async {
    final service = MirrorPublishTriggerService(
      baseUrl: 'http://127.0.0.1:8001',
      userId: '1',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/trigger')) {
          return http.Response('{"ok":true}', 200);
        }
        return http.Response(
          '{"ok":true,"status":"failed","running":false,'
          '"pending_reason":null,"last_error":"boom"}',
          200,
        );
      }),
    );

    await expectLater(
      service.trigger(
        reason: 'publish_click',
        documentId: 3245,
        immediate: true,
        waitForCompletion: true,
      ),
      throwsStateError,
    );
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
