import 'package:nx_db/nx_db.dart';

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
      struct[link] = {'id': true, 'name': true};
    }
  }

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

/// Sort newest [createdAt] first (ISO strings compare lexicographically for UTC).
List<Model> sortModelsByCreatedAtDesc(List<Model> models) {
  final out = [...models];
  out.sort((a, b) {
    final ca = a.createdAt ?? '';
    final cb = b.createdAt ?? '';
    return cb.compareTo(ca);
  });
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
