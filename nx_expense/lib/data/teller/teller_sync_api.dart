import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nx_db/auth.dart';

/// Same host normalization as [uploadExpenseSnapshot] (MCP `http_server.py`).
String _normalizeImageBaseForCf(String url) {
  var ep = url;
  if (CfAccess.endpointNeedsCfAccess(ep) && ep.startsWith('http://')) {
    ep = ep.replaceFirst('http://', 'https://');
  }
  return ep;
}

/// POST `{imageBaseUrl}/teller/sync` — sync Teller transactions into timeline events.
Future<TellerSyncResult> postTellerSync({
  required String imageBaseUrl,
  required String userId,
  http.Client? httpClient,
}) async {
  return _postExternalSync(
    imageBaseUrl: imageBaseUrl,
    userId: userId,
    path: '/teller/sync',
    label: 'Teller sync',
    httpClient: httpClient,
  );
}

/// POST `{imageBaseUrl}/bofa/sync` — sync BofA transactions into timeline events.
Future<TellerSyncResult> postBofaSync({
  required String imageBaseUrl,
  required String userId,
  http.Client? httpClient,
}) async {
  return _postExternalSync(
    imageBaseUrl: imageBaseUrl,
    userId: userId,
    path: '/bofa/sync',
    label: 'BofA sync',
    httpClient: httpClient,
  );
}

Future<TellerSyncResult> _postExternalSync({
  required String imageBaseUrl,
  required String userId,
  required String path,
  required String label,
  http.Client? httpClient,
}) async {
  final trimmed = imageBaseUrl.endsWith('/')
      ? imageBaseUrl.substring(0, imageBaseUrl.length - 1)
      : imageBaseUrl;
  final base = _normalizeImageBaseForCf(trimmed);
  final uri = Uri.parse('$base$path');
  final headers = <String, String>{'x-user-id': userId};
  if (CfAccess.shouldAttachHeaders(base)) {
    headers.addAll(CfAccess.headers);
  }
  final client = httpClient ?? http.Client();
  final closeClient = httpClient == null;
  try {
    final resp = await client.post(uri, headers: headers);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('$label failed (${resp.statusCode}): ${resp.body}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Invalid $label response');
    }
    if (decoded['ok'] != true) {
      final err = decoded['error']?.toString() ?? 'unknown error';
      throw StateError(err);
    }
    return TellerSyncResult.fromJson(decoded);
  } finally {
    if (closeClient) client.close();
  }
}

class TellerSyncResult {
  const TellerSyncResult({
    required this.accountsSynced,
    required this.counts,
    required this.raw,
  });

  final int? accountsSynced;
  final Map<String, dynamic> counts;
  final Map<String, dynamic> raw;

  factory TellerSyncResult.fromJson(Map<String, dynamic> json) {
    final rawCounts = json['counts'];
    return TellerSyncResult(
      accountsSynced: _asInt(json['accounts_synced']),
      counts: rawCounts is Map
          ? Map<String, dynamic>.from(rawCounts)
          : const {},
      raw: json,
    );
  }
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}
