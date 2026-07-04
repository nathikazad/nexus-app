import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

abstract class MirrorPublishTrigger {
  Future<void> trigger({
    required String reason,
    required int documentId,
    required bool immediate,
  });
}

class MirrorPublishTriggerService implements MirrorPublishTrigger {
  MirrorPublishTriggerService({
    required String baseUrl,
    required String userId,
    required http.Client client,
  }) : _baseUri = Uri.parse(_trimTrailingSlash(baseUrl)),
       _userId = userId,
       _client = client;

  final Uri _baseUri;
  final String _userId;
  final http.Client _client;

  @override
  Future<void> trigger({
    required String reason,
    required int documentId,
    required bool immediate,
  }) async {
    if (documentId <= 0) return;
    final response = await _client.post(
      _baseUri.resolve('/mirror/publish/trigger'),
      headers: {
        'X-User-Id': _userId,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'reason': reason,
        'document_id': documentId,
        'immediate': immediate,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('mirror publish trigger failed (${response.statusCode})');
    }
  }
}

String _trimTrailingSlash(String value) {
  return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}

void debugMirrorPublish(String message) {
  debugPrint('[nx_notes mirror publish] $message');
}
