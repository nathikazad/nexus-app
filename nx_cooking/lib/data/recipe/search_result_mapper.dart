import 'dart:convert';

import 'package:nx_cooking/domain/search_result.dart';

/// Parses the JSON array from `app.search_recipes` into domain rows.
List<RecipeSearchResult> searchResultsFromJson(dynamic raw) {
  final list = _asJsonList(raw);
  final out = <RecipeSearchResult>[];
  for (final item in list) {
    if (item is! Map) continue;
    final m = Map<String, dynamic>.from(item);
    final type = m['match_type']?.toString();
    switch (type) {
      case 'recipe':
        final id = _asInt(m['id']);
        final name = m['name']?.toString() ?? '';
        if (id != null) {
          out.add(RecipeSearchHit(id: id, name: name));
        }
      case 'CookingItem':
        final id = _asInt(m['id']);
        final name = m['name']?.toString() ?? '';
        if (id != null) {
          out.add(CookingItemSearchHit(id: id, name: name));
        }
      case 'tag':
        final tagNodeId = _asInt(m['tag_node_id']);
        final tagSystemId = _asInt(m['tag_system_id']);
        final tagName = m['tag_name']?.toString() ?? '';
        final tagSystemName = m['tag_system_name']?.toString() ?? '';
        if (tagNodeId != null && tagSystemId != null) {
          out.add(
            TagSearchHit(
              tagNodeId: tagNodeId,
              tagName: tagName,
              tagSystemId: tagSystemId,
              tagSystemName: tagSystemName,
            ),
          );
        }
      default:
        break;
    }
  }
  return out;
}

List<dynamic> _asJsonList(dynamic raw) {
  if (raw == null) return const [];
  if (raw is String) {
    final decoded = jsonDecode(raw);
    if (decoded is List) return decoded;
    return const [];
  }
  if (raw is List) return raw;
  return const [];
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}
