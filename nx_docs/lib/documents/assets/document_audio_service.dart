import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nx_docs/documents/document_models.dart';

class DocumentAudioService {
  DocumentAudioService({
    required String baseUrl,
    required String userId,
    http.Client? client,
  }) : _baseUri = Uri.parse(_trimTrailingSlash(baseUrl)),
       _userId = userId,
       _client = client ?? http.Client();

  final Uri _baseUri;
  final String _userId;
  final http.Client _client;

  Future<DocumentAudio> generate({
    required int documentId,
    bool overwrite = false,
  }) async {
    final response = await _client.post(
      _baseUri.resolve('/docs/audio/generate'),
      headers: <String, String>{
        'X-User-Id': _userId,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, Object>{
        'document_id': documentId,
        'language': 'en',
        'overwrite': overwrite,
      }),
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map) {
      throw StateError('Audio generation failed (${response.statusCode}).');
    }
    if (decoded['ok'] != true) {
      throw StateError(
        decoded['error']?.toString() ?? 'Audio generation failed.',
      );
    }
    final rawUrl = decoded['audio_url'];
    final sourceHash = decoded['audio_source_hash'];
    final manifest = DocumentAudioManifest.tryParse(decoded['audio_manifest']);
    if (rawUrl is! String || sourceHash is! String || manifest == null) {
      throw StateError('Audio generation returned an invalid response.');
    }
    return DocumentAudio(
      url: resolveUrl(rawUrl),
      sourceHash: sourceHash,
      manifest: manifest,
    );
  }

  String resolveUrl(String raw) {
    final uri = Uri.parse(raw);
    return uri.hasScheme ? raw : _baseUri.resolve(raw).toString();
  }

  void dispose() => _client.close();
}

String _trimTrailingSlash(String value) {
  return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}
