import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nx_db/auth.dart';
import 'package:teller_connect/teller_connect.dart';

String _normalizeMcpBaseForCf(String url) {
  var ep = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  if (CfAccess.endpointNeedsCfAccess(ep) && ep.startsWith('http://')) {
    ep = ep.replaceFirst('http://', 'https://');
  }
  return ep;
}

Map<String, String> _headers(
  String base,
  String userId, {
  bool jsonBody = false,
}) {
  final headers = <String, String>{'x-user-id': userId};
  if (jsonBody) headers['content-type'] = 'application/json';
  if (CfAccess.shouldAttachHeaders(base)) {
    headers.addAll(CfAccess.headers);
  }
  return headers;
}

class TellerLinkedAccount {
  const TellerLinkedAccount({
    required this.accountId,
    this.name,
    this.type,
    this.subtype,
    this.currency,
    this.lastFour,
    this.enrollmentId,
    this.institution,
    this.enabled = true,
  });

  final String accountId;
  final String? name;
  final String? type;
  final String? subtype;
  final String? currency;
  final String? lastFour;
  final String? enrollmentId;
  final String? institution;
  final bool enabled;

  factory TellerLinkedAccount.fromJson(Map<String, dynamic> json) {
    return TellerLinkedAccount(
      accountId: (json['account_id'] ?? '').toString(),
      name: json['name']?.toString(),
      type: json['type']?.toString(),
      subtype: json['subtype']?.toString(),
      currency: json['currency']?.toString(),
      lastFour: json['last_four']?.toString(),
      enrollmentId: json['enrollment_id']?.toString(),
      institution: json['institution']?.toString(),
      enabled: json['enabled'] != false,
    );
  }

  String get displayName {
    final n = name?.trim();
    if (n != null && n.isNotEmpty) return n;
    return accountId;
  }

  String get detailLine {
    final parts = <String>[
      if ((institution ?? '').trim().isNotEmpty) institution!.trim(),
      if ((subtype ?? type ?? '').trim().isNotEmpty) (subtype ?? type)!.trim(),
      if ((currency ?? '').trim().isNotEmpty) currency!.trim(),
      if ((lastFour ?? '').trim().isNotEmpty) '****${lastFour!.trim()}',
    ];
    return parts.join(' - ');
  }
}

Future<List<TellerLinkedAccount>> fetchTellerAccounts({
  required String imageBaseUrl,
  required String userId,
  http.Client? httpClient,
}) async {
  final base = _normalizeMcpBaseForCf(imageBaseUrl);
  final uri = Uri.parse('$base/teller/accounts');
  final client = httpClient ?? http.Client();
  final closeClient = httpClient == null;
  try {
    final resp = await client.get(uri, headers: _headers(base, userId));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'Teller accounts failed (${resp.statusCode}): ${resp.body}',
      );
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Invalid Teller accounts response');
    }
    if (decoded['ok'] != true) {
      throw StateError(decoded['error']?.toString() ?? 'unknown error');
    }
    final accounts = decoded['accounts'];
    if (accounts is! List) return const [];
    return [
      for (final row in accounts)
        if (row is Map<String, dynamic>) TellerLinkedAccount.fromJson(row),
    ];
  } finally {
    if (closeClient) client.close();
  }
}

Future<List<TellerLinkedAccount>> registerTellerEnrollment({
  required String imageBaseUrl,
  required String userId,
  required TellerData enrollment,
  http.Client? httpClient,
}) async {
  final base = _normalizeMcpBaseForCf(imageBaseUrl);
  final uri = Uri.parse('$base/teller/enrollment');
  final client = httpClient ?? http.Client();
  final closeClient = httpClient == null;
  try {
    final resp = await client.post(
      uri,
      headers: _headers(base, userId, jsonBody: true),
      body: jsonEncode({
        'access_token': enrollment.accessToken,
        'enrollment': enrollment.enrollment.toJson(),
      }),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'Teller enrollment failed (${resp.statusCode}): ${resp.body}',
      );
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Invalid Teller enrollment response');
    }
    if (decoded['ok'] != true) {
      throw StateError(decoded['error']?.toString() ?? 'unknown error');
    }
    final accounts = decoded['accounts'];
    if (accounts is! List) return const [];
    return [
      for (final row in accounts)
        if (row is Map<String, dynamic>) TellerLinkedAccount.fromJson(row),
    ];
  } finally {
    if (closeClient) client.close();
  }
}
