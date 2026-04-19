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

/// POST `{imageBaseUrl}/teller/sync` — [servers/mcp/http_server.py] `teller_sync`
/// (Teller API fetch, classify, apply to DB). Requires `X-User-Id` (see `_get_user_id`).
Future<void> postTellerSync({
  required String imageBaseUrl,
  required String userId,
}) async {
  final trimmed = imageBaseUrl.endsWith('/')
      ? imageBaseUrl.substring(0, imageBaseUrl.length - 1)
      : imageBaseUrl;
  final base = _normalizeImageBaseForCf(trimmed);
  final uri = Uri.parse('$base/teller/sync');
  final headers = <String, String>{
    'x-user-id': userId,
  };
  if (CfAccess.shouldAttachHeaders(base)) {
    headers.addAll(CfAccess.headers);
  }
  final resp = await http.post(uri, headers: headers);
  if (resp.statusCode < 200 || resp.statusCode >= 300) {
    throw StateError('Teller sync failed (${resp.statusCode}): ${resp.body}');
  }
  final decoded = jsonDecode(resp.body);
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Invalid teller sync response');
  }
  if (decoded['ok'] != true) {
    final err = decoded['error']?.toString() ?? 'unknown error';
    throw StateError(err);
  }
}
