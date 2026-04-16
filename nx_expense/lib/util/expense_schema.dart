import 'package:flutter/foundation.dart' show setEquals;
import 'package:nx_db/nx_db.dart';

import 'format.dart';

/// Hardcoded model type name — everything else is schema-driven.
const String kExpenseModelTypeName = 'Expense';
const String kTransferModelTypeName = 'Transfer';

/// Builds the `struct` for `get_kgql_models` from an Expense [ModelType] (§2.2).
Map<String, dynamic> buildExpenseStruct(ModelType schema) {
  final struct = <String, dynamic>{
    'id': true,
    'name': true,
    'description': true,
    'created_at': true,
    'tags': true,
  };

  for (final ad in schema.attributes ?? const <AttributeDefinition>[]) {
    final k = ad.key;
    if (k != null && k.isNotEmpty) {
      struct[k] = true;
    }
  }

  for (final rel in schema.relations ?? const <RelationshipType>[]) {
    final link = rel.link;
    if (link is String && link.isNotEmpty) {
      if (link == kTransferModelTypeName) {
        struct[link] = {
          'id': true,
          'name': true,
          'description': true,
          'created_at': true,
          'amount': true,
          'date': true,
          'to': true,
          'Company': {'id': true, 'name': true},
        };
      } else {
        struct[link] = {'id': true, 'name': true};
      }
    }
  }

  // Generic relations node: provides relation_id → model_id mapping for
  // delta-based updates (add new links / delete removed edges).
  struct['relations'] = {
    'relation_id': true,
    'model_id': true,
    'model_type': true,
  };

  return struct;
}

/// Builds the `struct` for `get_kgql_models` for Transfer (amount, date, `to`, `Company`, …).
Map<String, dynamic> buildTransferStruct(ModelType schema) {
  final struct = <String, dynamic>{
    'id': true,
    'name': true,
    'description': true,
    'created_at': true,
  };

  for (final ad in schema.attributes ?? const <AttributeDefinition>[]) {
    final k = ad.key;
    if (k != null && k.isNotEmpty) {
      struct[k] = true;
    }
  }

  for (final rel in schema.relations ?? const <RelationshipType>[]) {
    final link = rel.link;
    if (link is String && link.isNotEmpty) {
      struct[link] = {'id': true, 'name': true};
    }
  }

  // Generic relations node: edge IDs for add/remove on save (same as Expense struct).
  struct['relations'] = {
    'relation_id': true,
    'model_id': true,
    'model_type': true,
  };

  return struct;
}

/// Row title: Cash when `to` is Cash; otherwise linked Company name or model name.
String transferDisplayTitle(Model model) {
  final to = attributeValue(model, 'to');
  if (to is String && to.toLowerCase() == 'cash') {
    return 'Cash';
  }
  final companies = model.relations?['Company'];
  if (companies != null && companies.isNotEmpty) {
    return companies.first.name;
  }
  return model.name;
}

/// Transfer `amount` attribute when present on an embedded or full [Model].
num? transferAmountAttribute(Model model) {
  final raw = attributeValue(model, 'amount');
  if (raw is num) return raw;
  return num.tryParse('$raw');
}

/// Prefer `date` attribute for ordering; fall back to `created_at` (ISO strings).
String modelDateSortKey(Model m) {
  final raw = attributeValue(m, 'date');
  if (raw is String && raw.isNotEmpty) return normalizeDateAttributeSortKey(raw);
  return m.createdAt ?? '';
}

/// Prefers `date` attribute, otherwise `created_at` (for list/detail cells).
String modelDateCellLabel(Model model) {
  final raw = attributeValue(model, 'date');
  if (raw is String && raw.isNotEmpty) return formatModelDate(raw);
  return formatModelDate(model.createdAt);
}

/// Same as [modelDateCellLabel] (Transfer rows).
String transferCellDateLabel(Model model) => modelDateCellLabel(model);

/// First `number` attribute key in definition order (primary amount field).
String? primaryNumberAttributeKey(ModelType schema) {
  for (final ad in schema.attributes ?? const <AttributeDefinition>[]) {
    if (ad.valueType == 'number' && ad.key != null && ad.key!.isNotEmpty) {
      return ad.key;
    }
  }
  return null;
}

TagSystem? tagSystemByName(ModelType schema, String name) {
  for (final ts in schema.tagSystems ?? const <TagSystem>[]) {
    if (ts.name == name) return ts;
  }
  return null;
}

/// Distinct relation target type names (from `link` when it is a [String]).
Set<String> allRelationTargetTypeNames(ModelType schema) {
  final out = <String>{};
  for (final rel in schema.relations ?? const <RelationshipType>[]) {
    final link = rel.link;
    if (link is String && link.isNotEmpty) out.add(link);
  }
  return out;
}

/// Quick-filter chips: ≤6 root nodes → one chip per root; otherwise one chip that opens the system.
List<FilterChipDescriptor> filterChipDescriptors(ModelType schema) {
  const maxRootsForIndividualChips = 6;
  final list = <FilterChipDescriptor>[];
  for (final ts in schema.tagSystems ?? const <TagSystem>[]) {
    final roots = ts.nodes;
    if (roots.length <= maxRootsForIndividualChips) {
      for (final n in roots) {
        list.add(FilterChipDescriptor(
          systemName: ts.name,
          nodeName: n.name,
          label: n.name,
        ));
      }
    } else {
      list.add(FilterChipDescriptor(
        systemName: ts.name,
        nodeName: null,
        label: ts.name,
      ));
    }
  }
  return list;
}

class FilterChipDescriptor {
  final String systemName;
  final String? nodeName;
  final String label;

  const FilterChipDescriptor({
    required this.systemName,
    this.nodeName,
    required this.label,
  });
}

/// Primary attribute value for display (from [Model.attributes] map).
dynamic attributeValue(Model model, String key) {
  final a = model.attributes;
  if (a == null) return null;
  return a[key];
}

/// Display label for a schema attribute key (`cost`, `date-time`, `snake_case` → title words).
String formatAttributeLabel(String key) {
  if (key.isEmpty) return key;
  final parts = key.split(RegExp(r'[-_\s]+')).where((s) => s.isNotEmpty);
  return parts
      .map((p) => '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}')
      .join(' ');
}

/// Expense attribute that excludes a row from list totals when true.
const String kExpenseIgnoreAttributeKey = 'ignore';

/// True when the expense `ignore` flag is set (excluded from list count/sum).
bool expenseIgnoredForTotals(Model model) {
  final v = attributeValue(model, kExpenseIgnoreAttributeKey);
  if (v == true) return true;
  if (v == false) return false;
  if (v is String) {
    final s = v.trim().toLowerCase();
    return s == 'true' || s == '1';
  }
  return false;
}

/// Deduplicate [ids] in first-seen order. The API may list the same related model twice
/// (e.g. multiple relationship types), which would otherwise duplicate `link` payloads on save.
List<int> dedupeIntIdsPreserveOrder(List<int> ids) {
  final seen = <int>{};
  return [for (final id in ids) if (seen.add(id)) id];
}

/// Deduplicate [models] by [Model.id] in first-seen order (same as [dedupeIntIdsPreserveOrder] for lists).
List<Model> dedupeModelsById(List<Model> models) {
  final seen = <int>{};
  return [for (final m in models) if (seen.add(m.id)) m];
}

/// Equality for pending `ModelRelation.create` maps (e.g. name / description).
bool relationPendingCreateEquals(Map<String, dynamic>? a, Map<String, dynamic>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return a == b;
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}

/// Whether current relation picks match the snapshot taken after load (same link id sets, same creates).
///
/// Used with [shouldOmitRelationsOnExpenseUpdate] so updates do not re-send unchanged `relations`;
/// `set_kgql_models` treats `link` on update as additive and can duplicate edges.
bool relationStateMatchesSnapshotForUpdate({
  required Map<String, List<int>> linkIdsByType,
  required Map<String, Map<String, dynamic>?> createsByType,
  required Map<String, Set<int>> snapshotLinkIdsByType,
  required Map<String, Map<String, dynamic>?> snapshotCreatesByType,
}) {
  for (final k in linkIdsByType.keys) {
    final curIds = dedupeIntIdsPreserveOrder(linkIdsByType[k] ?? []).toSet();
    final snapIds = snapshotLinkIdsByType[k] ?? <int>{};
    if (!setEquals(curIds, snapIds)) return false;
    if (!relationPendingCreateEquals(createsByType[k], snapshotCreatesByType[k])) {
      return false;
    }
  }
  return true;
}

/// On expense **update**, omit `relations` in the save request when nothing changed.
bool shouldOmitRelationsOnExpenseUpdate({
  required int? expenseId,
  required Map<String, List<int>> linkIdsByType,
  required Map<String, Map<String, dynamic>?> createsByType,
  required Map<String, Set<int>> snapshotLinkIdsByType,
  required Map<String, Map<String, dynamic>?> snapshotCreatesByType,
}) {
  if (expenseId == null) return false;
  return relationStateMatchesSnapshotForUpdate(
    linkIdsByType: linkIdsByType,
    createsByType: createsByType,
    snapshotLinkIdsByType: snapshotLinkIdsByType,
    snapshotCreatesByType: snapshotCreatesByType,
  );
}

/// Sort by `date` attribute when set, else `created_at` (newest first).
List<Model> sortModelsByDateDesc(List<Model> models) {
  final out = [...models];
  out.sort((a, b) => modelDateSortKey(b).compareTo(modelDateSortKey(a)));
  return out;
}

/// Breadcrumb path from root to a leaf [nodeName] in a hierarchical [TagSystem].
List<String>? tagBreadcrumbPath(TagSystem system, String nodeName) {
  List<String>? walk(List<TagNode> nodes, List<String> prefix) {
    for (final n in nodes) {
      final path = [...prefix, n.name];
      if (n.name == nodeName) return path;
      final ch = n.children;
      if (ch != null && ch.isNotEmpty) {
        final sub = walk(ch, path);
        if (sub != null) return sub;
      }
    }
    return null;
  }

  return walk(system.nodes, []);
}

int countTagNodes(TagSystem ts) {
  int n = 0;
  void walk(List<TagNode> nodes) {
    for (final x in nodes) {
      n++;
      if (x.children != null) walk(x.children!);
    }
  }

  walk(ts.nodes);
  return n;
}

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

/// Spend-by-day: backend returns grouped rows whose `key` is a day bucket (often the Expense `date`
/// value, e.g. `2025-01-01`, or ISO timestamps when grouping on `created_at`).
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
              m['date'] ??
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
