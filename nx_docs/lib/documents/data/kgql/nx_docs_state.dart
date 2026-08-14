import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NxDocsStateService {
  NxDocsStateService({
    required String baseUrl,
    required String userId,
    required http.Client client,
  }) : _baseUri = Uri.parse(_trimTrailingSlash(baseUrl)),
       _userId = userId,
       _client = client;

  final Uri _baseUri;
  final String _userId;
  final http.Client _client;

  Future<int?> loadLastDocumentId() async {
    final uri = _baseUri.resolve('/docs/state/nx_docs');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('nx_docs state load failed (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      return null;
    }
    final nxDocs = decoded['nx_docs'];
    if (nxDocs is! Map) {
      return null;
    }
    return _positiveInt(nxDocs['last_document_id']);
  }

  Future<void> saveLastDocumentId(int documentId) async {
    if (documentId <= 0) {
      return;
    }
    final uri = _baseUri.resolve('/docs/state/nx_docs');
    final response = await _client.put(
      uri,
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'last_document_id': documentId}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('nx_docs state save failed (${response.statusCode})');
    }
  }

  Map<String, String> get _headers => {'X-User-Id': _userId};
}

int? _positiveInt(Object? value) {
  final parsed = switch (value) {
    int() => value,
    num() => value.toInt(),
    String() => int.tryParse(value),
    _ => null,
  };
  return parsed != null && parsed > 0 ? parsed : null;
}

String _trimTrailingSlash(String value) {
  return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}

void debugNxDocsState(String message) {
  debugPrint('[nx_docs state] $message');
}
