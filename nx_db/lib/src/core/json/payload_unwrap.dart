import 'dart:convert';

/// Decodes PostGraphile / KGQL payloads that may be a JSON string or a list.
List<dynamic> unwrapJsonList(dynamic jsonResult) {
  if (jsonResult == null) return [];
  if (jsonResult is String) {
    return json.decode(jsonResult) as List<dynamic>;
  }
  return jsonResult as List<dynamic>;
}

/// Decodes a JSON object from string or map; returns null if not parseable.
Map<String, dynamic>? unwrapJsonMap(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is String) {
    final d = json.decode(raw);
    if (d is Map<String, dynamic>) return d;
    if (d is Map) return Map<String, dynamic>.from(d);
  }
  return null;
}
