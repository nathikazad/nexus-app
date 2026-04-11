import 'package:nx_db/nx_db.dart';

/// Hardcoded model type name — everything else is schema-driven.
const String kExpenseModelTypeName = 'Expense';

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
      struct[link] = {'id': true, 'name': true};
    }
  }

  return struct;
}

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
