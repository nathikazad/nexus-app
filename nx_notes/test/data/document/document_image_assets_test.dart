import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_notes/data/document/document_image_assets.dart';

void main() {
  test('parses document image asset urls', () {
    final ref = DocumentImageAssetRef.tryParse(
      'https://nexus.nathikazad.com/notes/assets/images/file?user_id=1&document_id=4209&name=abc.png',
    );

    expect(ref, isNotNull);
    expect(ref!.userId, 1);
    expect(ref.documentId, 4209);
    expect(ref.name, 'abc.png');
    expect(
      ref.relativeUrl,
      '/notes/assets/images/file?user_id=1&document_id=4209&name=abc.png',
    );
  });

  test('rejects non-document image urls', () {
    expect(
      DocumentImageAssetRef.tryParse('https://example.com/image.png'),
      isNull,
    );
    expect(
      DocumentImageAssetRef.tryParse(
        '/notes/assets/images/file?user_id=1&document_id=4209&name=../x.png',
      ),
      isNull,
    );
  });

  test(
    'external network urls are not uploaded, resolved, or deleted',
    () async {
      var requestCount = 0;
      final service = DocumentImageAssetService(
        baseUrl: 'http://127.0.0.1:8001',
        userId: '1',
        client: MockClient((request) async {
          requestCount += 1;
          return http.Response('{}', 500);
        }),
      );

      expect(
        await service.storeImageSource(
          documentId: 4209,
          source: 'https://example.com/image.png',
        ),
        'https://example.com/image.png',
      );
      expect(
        service.resolveImageUrl('https://example.com/image.png'),
        'https://example.com/image.png',
      );
      expect(
        await service.deleteImageUrl('https://example.com/image.png'),
        false,
      );
      expect(requestCount, 0);
    },
  );

  test('uploads raw base64 image bytes and returns relative url', () async {
    late http.Request seen;
    final service = DocumentImageAssetService(
      baseUrl: 'http://100.108.43.37:8001',
      userId: '7',
      client: MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode(<String, Object?>{
            'ok': true,
            'url':
                '/notes/assets/images/file?user_id=7&document_id=4209&name=abc.png',
          }),
          200,
        );
      }),
    );

    final url = await service.storeImageSource(
      documentId: 4209,
      source: base64Encode(<int>[0x89, 0x50, 0x4e, 0x47, 1, 2, 3, 4]),
    );

    expect(
      url,
      '/notes/assets/images/file?user_id=7&document_id=4209&name=abc.png',
    );
    expect(seen.method, 'POST');
    expect(
      seen.url.toString(),
      'http://100.108.43.37:8001/notes/assets/images',
    );
    expect(seen.headers['X-User-Id'], '7');
    final multipartBody = latin1.decode(seen.bodyBytes);
    expect(multipartBody, contains('name="document_id"'));
    expect(multipartBody, contains('4209'));
    expect(multipartBody, contains('filename="document-image-'));
    expect(multipartBody, contains('.png"'));
  });

  test('resolves relative document image urls against active image base', () {
    final tailscaleService = DocumentImageAssetService(
      baseUrl: 'http://100.108.43.37:8001',
      userId: '1',
      client: MockClient((request) async => http.Response('{}', 500)),
    );
    final wanService = DocumentImageAssetService(
      baseUrl: 'https://nexus.nathikazad.com',
      userId: '1',
      client: MockClient((request) async => http.Response('{}', 500)),
    );

    const storedUrl =
        '/notes/assets/images/file?user_id=1&document_id=4209&name=abc.png';

    expect(
      tailscaleService.resolveImageUrl(storedUrl),
      'http://100.108.43.37:8001/notes/assets/images/file?user_id=1&document_id=4209&name=abc.png',
    );
    expect(
      wanService.resolveImageUrl(storedUrl),
      'https://nexus.nathikazad.com/notes/assets/images/file?user_id=1&document_id=4209&name=abc.png',
    );
  });

  test(
    'deletes relative document image urls through the active image base',
    () async {
      late http.Request seen;
      final service = DocumentImageAssetService(
        baseUrl: 'https://nexus.nathikazad.com',
        userId: '1',
        client: MockClient((request) async {
          seen = request;
          return http.Response('{"ok":true,"deleted":true}', 200);
        }),
      );

      final deleted = await service.deleteImageUrl(
        '/notes/assets/images/file?user_id=1&document_id=4209&name=abc.jpg',
      );

      expect(deleted, true);
      expect(seen.method, 'DELETE');
      expect(
        seen.url.toString(),
        'https://nexus.nathikazad.com/notes/assets/images/file?user_id=1&document_id=4209&name=abc.jpg',
      );
    },
  );
}
