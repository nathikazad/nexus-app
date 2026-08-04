import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_cards/data/audio/http_card_audio_repository.dart';

void main() {
  test('fetch resolves relative audio URL and sends user header', () async {
    late Uri requested;
    late Map<String, String> headers;
    final client = MockClient((request) async {
      requested = request.url;
      headers = request.headers;
      return http.Response.bytes([0x49, 0x44, 0x33], 200);
    });
    final repository = HttpCardAudioRepository(
      baseUrl: 'http://100.108.43.37:8001',
      userId: '7',
      httpClient: client,
    );

    final bytes = await repository.fetch(
      '/cards/assets/audio/file?user_id=7&name=12-abcd.mp3',
    );

    expect(
      requested.toString(),
      'http://100.108.43.37:8001/cards/assets/audio/file?user_id=7&name=12-abcd.mp3',
    );
    expect(headers['x-user-id'], '7');
    expect(bytes, [0x49, 0x44, 0x33]);
  });

  test('fetch reports HTTP failure without returning response bytes', () async {
    final repository = HttpCardAudioRepository(
      baseUrl: 'https://nexus.nathikazad.com',
      userId: '1',
      httpClient: MockClient((_) async => http.Response('missing', 404)),
    );

    expect(
      () => repository.fetch('/cards/assets/audio/file?name=missing.mp3'),
      throwsA(isA<CardAudioFetchException>()),
    );
  });
}
