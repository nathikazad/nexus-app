/// Parse `getKgqlAggregate` maps for chart labels/values (shape varies by backend).
List<MapEntry<String, double>> parseGroupedChartEntries(Map<String, dynamic> raw) {
  final g = raw['grouped'];
  if (g is! List) return [];
  final out = <MapEntry<String, double>>[];
  for (final item in g) {
    if (item is Map) {
      final m = Map<String, dynamic>.from(item);
      final label = (m['group_key'] ?? m['name'] ?? m['label'] ?? m['key'] ?? '').toString();
      final v = m['aggregated_value'] ?? m['value'];
      if (label.isEmpty) continue;
      if (v is num) {
        out.add(MapEntry(label, v.toDouble()));
      }
    }
  }
  return out;
}

/// Spend-by-day: backend returns `[{ "key": "2025-01-01T00:00:00", "aggregated_value": ... }]`
/// (see `servers/pgdb/docs/human-reference/get_kgql_aggregate.md` — same `key` field as other groupings).
List<MapEntry<String, double>> parseDaySpendEntries(Map<String, dynamic> raw) {
  final g = raw['grouped'];
  if (g is! List) return [];
  final out = <MapEntry<String, double>>[];
  for (final item in g) {
    if (item is Map) {
      final m = Map<String, dynamic>.from(item);
      final label = (m['group_key'] ??
              m['key'] ??
              m['name'] ??
              m['label'] ??
              m['day'] ??
              m['created_at'] ??
              '')
          .toString();
      final v = m['aggregated_value'] ?? m['value'];
      if (label.isEmpty) continue;
      if (v is num) {
        out.add(MapEntry(label, v.toDouble()));
      }
    }
  }
  if (out.isEmpty && raw['aggregated_value'] is num) {
    return [MapEntry('total', (raw['aggregated_value'] as num).toDouble())];
  }
  return out;
}
