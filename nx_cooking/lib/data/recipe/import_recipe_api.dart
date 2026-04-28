import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nx_db/auth.dart';

String _normalizeImageBaseForCf(String url) {
  var ep = url;
  if (CfAccess.endpointNeedsCfAccess(ep) && ep.startsWith('http://')) {
    ep = ep.replaceFirst('http://', 'https://');
  }
  return ep;
}

String _trimBase(String imageBaseUrl) {
  return imageBaseUrl.endsWith('/')
      ? imageBaseUrl.substring(0, imageBaseUrl.length - 1)
      : imageBaseUrl;
}

Map<String, String> _mcpHeaders(String base, String userId, {bool jsonBody = false}) {
  final headers = <String, String>{'x-user-id': userId};
  if (jsonBody) {
    headers['Content-Type'] = 'application/json';
  }
  if (CfAccess.shouldAttachHeaders(base)) {
    headers.addAll(CfAccess.headers);
  }
  return headers;
}

/// Parsed success payload from `POST /import-recipe` (MCP `http_server.py`: `import_recipe`).
class ImportRecipeHttpResult {
  const ImportRecipeHttpResult({
    required this.recipeId,
    required this.createdItemIds,
    required this.recipe,
  });

  final int recipeId;
  final List<int> createdItemIds;
  final Map<String, dynamic> recipe;
}

ImportRecipeHttpResult _parseOkBody(Map<String, dynamic> decoded) {
  final rid = decoded['recipe_id'];
  if (rid is! num) {
    throw StateError('import-recipe: missing recipe_id');
  }

  final rawIds = decoded['created_item_ids'];
  final created = <int>[];
  if (rawIds is List<dynamic>) {
    for (final x in rawIds) {
      if (x is num) created.add(x.toInt());
    }
  }

  final recipe = decoded['recipe'];
  if (recipe is! Map<String, dynamic>) {
    throw StateError('import-recipe: missing or invalid recipe');
  }

  return ImportRecipeHttpResult(
    recipeId: rid.toInt(),
    createdItemIds: created,
    recipe: recipe,
  );
}

Never _throwFromResponse(http.Response resp) {
  Map<String, dynamic>? decoded;
  try {
    final o = jsonDecode(resp.body);
    if (o is Map<String, dynamic>) decoded = o;
  } catch (_) {
    // Best-effort error parsing.
  }
  final msg =
      decoded?['error']?.toString() ??
      (resp.body.isNotEmpty ? resp.body : 'HTTP ${resp.statusCode}');
  throw StateError('import-recipe failed (${resp.statusCode}): $msg');
}

/// `POST {imageBaseUrl}/import-recipe` with body `{"url":"..."}` — crawler fetch + KGQL insert.
Future<ImportRecipeHttpResult> importRecipeFromUrl({
  required String imageBaseUrl,
  required String userId,
  required String recipeUrl,
}) async {
  final base = _normalizeImageBaseForCf(_trimBase(imageBaseUrl));
  final uri = Uri.parse('$base/import-recipe');
  final resp = await http.post(
    uri,
    headers: _mcpHeaders(base, userId, jsonBody: true),
    body: jsonEncode(<String, dynamic>{'url': recipeUrl}),
  );
  if (resp.statusCode < 200 || resp.statusCode >= 300) {
    _throwFromResponse(resp);
  }
  final decoded = jsonDecode(resp.body);
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Invalid import-recipe response');
  }
  if (decoded['ok'] != true) {
    _throwFromResponse(resp);
  }
  return _parseOkBody(decoded);
}

/// `POST {imageBaseUrl}/import-recipe` with body `{"text":"..."}` — pasted recipe text.
Future<ImportRecipeHttpResult> importRecipeFromPastedText({
  required String imageBaseUrl,
  required String userId,
  required String recipeText,
}) async {
  final base = _normalizeImageBaseForCf(_trimBase(imageBaseUrl));
  final uri = Uri.parse('$base/import-recipe');
  final resp = await http.post(
    uri,
    headers: _mcpHeaders(base, userId, jsonBody: true),
    body: jsonEncode(<String, dynamic>{'text': recipeText}),
  );
  if (resp.statusCode < 200 || resp.statusCode >= 300) {
    _throwFromResponse(resp);
  }
  final decoded = jsonDecode(resp.body);
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Invalid import-recipe response');
  }
  if (decoded['ok'] != true) {
    _throwFromResponse(resp);
  }
  return _parseOkBody(decoded);
}
