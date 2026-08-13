import 'dart:convert';

import '../core/json/payload_unwrap.dart';

/// ISO date `YYYY-MM-DD` to local date at midnight.
DateTime? parseDateOnly(dynamic raw) {
  if (raw == null) return null;
  if (raw is String) {
    if (raw.isEmpty) return null;
    return DateTime.parse(raw);
  }
  if (raw is DateTime) return raw;
  return null;
}

/// Coerce PostGraphile JSON to [Map] (object or string).
Map<String, dynamic>? parseJsonObject(dynamic raw) {
  return unwrapJsonMap(raw);
}

/// [num] or stringified number.
num? parseNumLoose(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) return raw;
  if (raw is String) return num.tryParse(raw);
  return null;
}

/// Unwraps a goals JSON field that may be a [Map] or a JSON [String].
Map<String, dynamic>? unwrapObjectField(dynamic field) {
  if (field == null) return null;
  if (field is Map<String, dynamic>) return field;
  if (field is Map) return Map<String, dynamic>.from(field);
  if (field is String) {
    final d = json.decode(field);
    if (d is Map<String, dynamic>) return d;
    if (d is Map) return Map<String, dynamic>.from(d);
  }
  return null;
}
