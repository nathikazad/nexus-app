import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nx_db/auth.dart';
import 'package:nx_expense/domain/teller/teller_expense_review.dart';

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
Future<TellerSyncResult> postTellerSync({
  required String imageBaseUrl,
  required String userId,
  http.Client? httpClient,
}) async {
  final trimmed = imageBaseUrl.endsWith('/')
      ? imageBaseUrl.substring(0, imageBaseUrl.length - 1)
      : imageBaseUrl;
  final base = _normalizeImageBaseForCf(trimmed);
  final uri = Uri.parse('$base/teller/sync');
  final headers = <String, String>{'x-user-id': userId};
  if (CfAccess.shouldAttachHeaders(base)) {
    headers.addAll(CfAccess.headers);
  }
  final client = httpClient ?? http.Client();
  final closeClient = httpClient == null;
  try {
    final resp = await client.post(uri, headers: headers);
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
    return TellerSyncResult.fromJson(decoded);
  } finally {
    if (closeClient) client.close();
  }
}

Future<TellerExpenseReviewApplyResult> applyTellerExpenseReview({
  required String imageBaseUrl,
  required String userId,
  required int domainId,
  required List<Map<String, dynamic>> decisions,
  http.Client? httpClient,
}) async {
  final trimmed = imageBaseUrl.endsWith('/')
      ? imageBaseUrl.substring(0, imageBaseUrl.length - 1)
      : imageBaseUrl;
  final base = _normalizeImageBaseForCf(trimmed);
  final uri = Uri.parse('$base/teller/expense-review/apply');
  final headers = <String, String>{
    'content-type': 'application/json',
    'x-user-id': userId,
  };
  if (CfAccess.shouldAttachHeaders(base)) {
    headers.addAll(CfAccess.headers);
  }
  final client = httpClient ?? http.Client();
  final closeClient = httpClient == null;
  try {
    final resp = await client.post(
      uri,
      headers: headers,
      body: jsonEncode({'domain_id': domainId, 'decisions': decisions}),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'Teller expense review failed (${resp.statusCode}): ${resp.body}',
      );
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Invalid teller expense review response');
    }
    if (decoded['ok'] != true) {
      final err = decoded['error']?.toString() ?? 'unknown error';
      throw StateError(err);
    }
    return TellerExpenseReviewApplyResult.fromJson(decoded);
  } finally {
    if (closeClient) client.close();
  }
}
