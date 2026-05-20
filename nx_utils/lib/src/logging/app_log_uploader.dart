import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

String httpBaseFromSocketUrl(String socketUrl) {
  final uri = Uri.parse(socketUrl);
  if (uri.host == 'socket.nathikazad.com') {
    return 'https://nexus.nathikazad.com';
  }
  final scheme = uri.scheme == 'wss' ? 'https' : 'http';
  final port = uri.hasPort && uri.port == 8002 ? 8001 : uri.port;
  return Uri(
    scheme: scheme,
    host: uri.host,
    port: port,
  ).toString().replaceAll(RegExp(r'/+$'), '');
}

class NxAppLogUploader {
  NxAppLogUploader({
    required String httpBaseUrl,
    required this.origin,
    Map<String, String> headers = const {},
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 5),
  })  : _httpBaseUrl = httpBaseUrl.replaceAll(RegExp(r'/+$'), ''),
        _headers = Map<String, String>.from(headers),
        _client = httpClient;

  final String _httpBaseUrl;
  final String origin;
  final Map<String, String> _headers;
  final http.Client? _client;
  final Duration timeout;

  Future<void> upload({
    required String eventName,
    required String category,
    required String message,
    required Map<String, dynamic> payload,
    String severity = 'info',
    String originKind = 'app',
    DateTime? time,
  }) async {
    if (_httpBaseUrl.isEmpty) return;
    final uri = Uri.parse('$_httpBaseUrl/logs/app/upload');
    final row = {
      'time': (time ?? DateTime.now().toUtc()).toIso8601String(),
      'origin_kind': originKind,
      'origin': origin,
      'severity': severity,
      'event_name': eventName,
      'category': category,
      'message': message,
      'payload': payload,
    };
    final client = _client ?? http.Client();
    final ownsClient = _client == null;
    try {
      final response = await client
          .post(
            uri,
            headers: {
              ..._headers,
              'content-type': 'application/json',
            },
            body: jsonEncode({'row': row}),
          )
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          '[nx_utils logs] upload failed: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('[nx_utils logs] upload error: $e');
    } finally {
      if (ownsClient) client.close();
    }
  }
}
