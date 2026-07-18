import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nx_db/auth.dart';

import 'package:nx_expense/domain/suggestion/expense_suggestion.dart';

String normalizeSuggestionHttpBase(String url) {
  var value = url.trim();
  while (value.endsWith('/')) {
    value = value.substring(0, value.length - 1);
  }
  if (CfAccess.endpointNeedsCfAccess(value) && value.startsWith('http://')) {
    value = value.replaceFirst('http://', 'https://');
  }
  return value;
}

Map<String, String> suggestionHttpHeaders(String base, String userId) {
  final headers = <String, String>{'x-user-id': userId};
  if (CfAccess.shouldAttachHeaders(base)) headers.addAll(CfAccess.headers);
  return headers;
}

String resolveSuggestionAssetUrl(String imageBaseUrl, String path) {
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  final base = normalizeSuggestionHttpBase(imageBaseUrl);
  return '$base/${path.replaceFirst(RegExp(r'^/+'), '')}';
}

Future<List<ExpenseSuggestion>> fetchExpenseSuggestions({
  required String imageBaseUrl,
  required String userId,
  http.Client? httpClient,
}) async {
  final base = normalizeSuggestionHttpBase(imageBaseUrl);
  final uri = Uri.parse('$base/suggestions').replace(
    queryParameters: const {
      'status': 'open',
      'kind': 'transaction_expense',
      'limit': '500',
    },
  );
  final client = httpClient ?? http.Client();
  try {
    final response = await client.get(
      uri,
      headers: suggestionHttpHeaders(base, userId),
    );
    final body = _decodeObject(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['ok'] != true) {
      throw StateError(_errorMessage(body, response.statusCode));
    }
    final result = <ExpenseSuggestion>[];
    final cases = body['cases'];
    if (cases is List) {
      for (final rawCase in cases.whereType<Map>()) {
        final suggestions = rawCase['suggestions'];
        if (suggestions is! List) continue;
        for (final raw in suggestions.whereType<Map>()) {
          result.add(
            ExpenseSuggestion.fromJson(Map<String, dynamic>.from(raw)),
          );
        }
      }
    }
    return result;
  } finally {
    if (httpClient == null) client.close();
  }
}

Future<void> decideExpenseSuggestion({
  required String imageBaseUrl,
  required String userId,
  required int suggestionId,
  required bool accept,
  http.Client? httpClient,
}) async {
  final base = normalizeSuggestionHttpBase(imageBaseUrl);
  final action = accept ? 'accept' : 'reject';
  final uri = Uri.parse('$base/suggestions/$suggestionId/$action');
  final client = httpClient ?? http.Client();
  try {
    final response = await client.post(
      uri,
      headers: suggestionHttpHeaders(base, userId),
    );
    final body = _decodeObject(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['ok'] != true) {
      throw StateError(_errorMessage(body, response.statusCode));
    }
  } finally {
    if (httpClient == null) client.close();
  }
}

Future<void> reviseExpenseSuggestion({
  required String imageBaseUrl,
  required String userId,
  required int suggestionId,
  required String note,
  http.Client? httpClient,
}) async {
  final base = normalizeSuggestionHttpBase(imageBaseUrl);
  final uri = Uri.parse('$base/suggestions/$suggestionId/revise');
  final client = httpClient ?? http.Client();
  try {
    final response = await client.post(
      uri,
      headers: {
        ...suggestionHttpHeaders(base, userId),
        'content-type': 'application/json',
      },
      body: jsonEncode({'note': note}),
    );
    final body = _decodeObject(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['ok'] != true) {
      throw StateError(_errorMessage(body, response.statusCode));
    }
  } finally {
    if (httpClient == null) client.close();
  }
}

Map<String, dynamic> _decodeObject(String body) {
  try {
    final value = jsonDecode(body);
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  } on FormatException {
    return const {};
  }
}

String _errorMessage(Map<String, dynamic> body, int statusCode) {
  return body['message']?.toString() ??
      body['error']?.toString() ??
      'Suggestion request failed ($statusCode)';
}
