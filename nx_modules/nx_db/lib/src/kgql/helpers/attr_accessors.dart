import '../models/model.dart';

/// Typed reads from [Model.attributes] (flat map from `get_kgql_models`).
extension ModelAttrReads on Model {
  String? attrString(String key) {
    final raw = attributes?[key];
    if (raw == null) return null;
    if (raw is String) {
      final t = raw.trim();
      return t.isEmpty ? null : raw;
    }
    final s = raw.toString().trim();
    return s.isEmpty ? null : s;
  }

  int? attrInt(String key) {
    final raw = attributes?[key];
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is double) return raw.round();
    return int.tryParse(raw.toString());
  }

  double? attrDouble(String key) {
    final raw = attributes?[key];
    if (raw == null) return null;
    if (raw is double) return raw;
    if (raw is int) return raw.toDouble();
    return double.tryParse(raw.toString());
  }

  bool? attrBool(String key) {
    final raw = attributes?[key];
    if (raw == null) return null;
    if (raw is bool) return raw;
    final s = raw.toString().toLowerCase();
    if (s == 'true') return true;
    if (s == 'false') return false;
    return null;
  }

  /// Parses ISO-8601 strings; returns null if missing or invalid.
  DateTime? attrDateTime(String key) {
    final raw = attributes?[key];
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return DateTime.tryParse(raw.toString());
  }
}
