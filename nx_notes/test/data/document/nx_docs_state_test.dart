import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_notes/data/document/nx_docs_state.dart';

void main() {
  test('loads last document id from nx_docs state endpoint', () async {
    late http.Request seen;
    final service = NxDocsStateService(
      baseUrl: 'http://100.108.43.37:8001',
      userId: '7',
      client: MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({
            'ok': true,
            'nx_docs': {'last_document_id': 4209},
          }),
          200,
        );
      }),
    );

    final documentId = await service.loadLastDocumentId();

    expect(documentId, 4209);
    expect(seen.method, 'GET');
    expect(seen.url.toString(), 'http://100.108.43.37:8001/docs/state/nx_docs');
    expect(seen.headers['X-User-Id'], '7');
  });

  test('saves last document id to nx_docs state endpoint', () async {
    late http.Request seen;
    final service = NxDocsStateService(
      baseUrl: 'https://nexus.nathikazad.com',
      userId: '1',
      client: MockClient((request) async {
        seen = request;
        return http.Response('{"ok":true}', 200);
      }),
    );

    await service.saveLastDocumentId(4293);

    expect(seen.method, 'PUT');
    expect(
      seen.url.toString(),
      'https://nexus.nathikazad.com/docs/state/nx_docs',
    );
    expect(seen.headers['X-User-Id'], '1');
    expect(jsonDecode(seen.body), {'last_document_id': 4293});
  });

  test('load returns null for missing nx_docs state', () async {
    final service = NxDocsStateService(
      baseUrl: 'http://127.0.0.1:8001',
      userId: '1',
      client: MockClient((request) async {
        return http.Response('{"ok":true,"nx_docs":{}}', 200);
      }),
    );

    expect(await service.loadLastDocumentId(), isNull);
  });
}
