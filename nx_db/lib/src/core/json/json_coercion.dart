/// JSON helpers shared by KGQL model parsing.
int modelJsonInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

int? jsonIntNullable(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v);
  return null;
}

/// Coerces `description` (and similar) when the API returns a [String], a [List]
/// of lines (e.g. Teller / transaction payloads), or other scalar JSON.
String? parseOptionalStringField(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is List) {
    final parts = value
        .map((e) => e == null ? '' : e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    return parts.join('\n');
  }
  return value.toString();
}
