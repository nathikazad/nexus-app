import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_people/data/log/log_image_upload_service.dart';

void main() {
  test('uploads an image and returns the stored relative image URL', () async {
    late http.Request seen;
    final service = LogImageUploadService(
      baseUrl: 'https://nexus.example/',
      client: MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode(<String, Object?>{
            'ok': true,
            'filename': '260827120000.jpg',
            'image_url': '/images/file?name=260827120000.jpg',
          }),
          200,
        );
      }),
    );

    final result = await service.upload(
      bytes: <int>[0xff, 0xd8, 0xff, 0xd9],
      filename: 'photo.jpg',
    );

    expect(result, '/images/file?name=260827120000.jpg');
    expect(seen.method, 'POST');
    expect(seen.url.toString(), 'https://nexus.example/snapshots');
    final body = latin1.decode(seen.bodyBytes);
    expect(body, contains('name="source"'));
    expect(body, contains('people_app'));
    expect(body, contains('filename="photo.jpg"'));
  });
}
