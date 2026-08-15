import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_db/nx_db.dart';

class HttpCardAudioRepository implements CardAudioRepository {
  const HttpCardAudioRepository({
    required this.baseUrl,
    required this.userId,
    this.httpClient,
  });

  final String baseUrl;
  final String userId;
  final http.Client? httpClient;

  Uri _resolve(String audioUrl) {
    final base = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/');
    final parsed = Uri.parse(audioUrl);
    return parsed.hasScheme ? parsed : base.resolveUri(parsed);
  }

  @override
  Future<Uint8List> fetch(String audioUrl) async {
    final client = httpClient ?? http.Client();
    final closeClient = httpClient == null;
    try {
      final response = await client.get(
        _resolve(audioUrl),
        headers: imageHeaders(userId),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CardAudioFetchException(
          'Audio download failed: HTTP ${response.statusCode}',
        );
      }
      if (response.bodyBytes.isEmpty) {
        throw const CardAudioFetchException('Audio download was empty');
      }
      return response.bodyBytes;
    } finally {
      if (closeClient) client.close();
    }
  }
}

class CardAudioFetchException implements Exception {
  const CardAudioFetchException(this.message);

  final String message;

  @override
  String toString() => message;
}
