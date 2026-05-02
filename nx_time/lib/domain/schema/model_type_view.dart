// App-local, nx_db-free snapshot of ModelType for UI (forms, pickers, lists).

class ModelTypeView {
  const ModelTypeView({
    required this.id,
    required this.name,
    this.typeKind,
    this.attributes = const [],
    this.relations = const [],
    this.tagSystems = const [],
  });

  final int id;
  final String name;
  final String? typeKind;
  final List<AttributeDefView> attributes;
  final List<RelationTypeView> relations;
  final List<TagSystemView> tagSystems;

  String? get primaryNumberAttributeKey {
    for (final ad in attributes) {
      if (ad.valueType == 'number' && ad.key != null && ad.key!.isNotEmpty) {
        return ad.key;
      }
    }
    return null;
  }
}

class AttributeDefView {
  const AttributeDefView({
    this.id,
    this.key,
    this.valueType,
    this.required = false,
    this.constraints,
  });

  final int? id;
  final String? key;
  final String? valueType;
  final bool required;
  final Map<String, dynamic>? constraints;
}

class RelationTypeView {
  const RelationTypeView({
    this.id,
    required this.link,
    this.multiplicity,
    this.description,
  });

  final int? id;

  /// Target model type name.
  final String link;
  final String? multiplicity;
  final String? description;
}

class TagSystemView {
  const TagSystemView({
    this.id,
    required this.name,
    required this.selectionMode,
    required this.isHierarchical,
    required this.nodes,
  });

  final int? id;
  final String name;
  final String selectionMode;
  final bool isHierarchical;
  final List<TagNodeView> nodes;
}

class TagNodeView {
  const TagNodeView({this.id, required this.name, this.children});

  final int? id;
  final String name;
  final List<TagNodeView>? children;
}

class FilterChipDescriptor {
  const FilterChipDescriptor({
    required this.systemName,
    this.nodeName,
    required this.label,
  });

  final String systemName;
  final String? nodeName;
  final String label;
}

List<FilterChipDescriptor> filterChipDescriptors(ModelTypeView schema) {
  const maxRootsForIndividualChips = 6;
  final list = <FilterChipDescriptor>[];
  for (final ts in schema.tagSystems) {
    final roots = ts.nodes;
    if (roots.length <= maxRootsForIndividualChips) {
      for (final n in roots) {
        list.add(
          FilterChipDescriptor(
            systemName: ts.name,
            nodeName: n.name,
            label: n.name,
          ),
        );
      }
    } else {
      list.add(
        FilterChipDescriptor(
          systemName: ts.name,
          nodeName: null,
          label: ts.name,
        ),
      );
    }
  }
  return list;
}

TagSystemView? tagSystemByName(ModelTypeView schema, String name) {
  for (final ts in schema.tagSystems) {
    if (ts.name == name) return ts;
  }
  return null;
}

Set<String> allRelationTargetTypeNames(ModelTypeView schema) {
  final out = <String>{};
  for (final rel in schema.relations) {
    if (rel.link.isNotEmpty) out.add(rel.link);
  }
  return out;
}

List<String>? tagBreadcrumbPath(TagSystemView system, String nodeName) {
  List<String>? walk(List<TagNodeView> nodes, List<String> prefix) {
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

int countTagNodes(TagSystemView ts) {
  var n = 0;
  void walk(List<TagNodeView> nodes) {
    for (final x in nodes) {
      n++;
      if (x.children != null) walk(x.children!);
    }
  }

  walk(ts.nodes);
  return n;
}
