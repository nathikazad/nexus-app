import 'package:nx_db/kgql.dart';

import 'package:nx_expense/domain/schema/model_type_view.dart';

ModelTypeView modelTypeViewFromKgql(ModelType m) {
  return ModelTypeView(
    id: m.id,
    name: m.name,
    typeKind: m.typeKind,
    attributes: [
      for (final ad in m.attributes ?? const <AttributeDefinition>[])
        AttributeDefView(
          id: ad.id,
          key: ad.key,
          valueType: ad.valueType,
          required: ad.required,
          constraints: ad.constraints,
        ),
    ],
    relations: [
      for (final rel in m.relations ?? const <RelationshipType>[])
        if (_linkName(rel.link) != null)
          RelationTypeView(
            id: rel.id,
            link: _linkName(rel.link)!,
            multiplicity: rel.multiplicity,
            description: rel.description,
          ),
    ],
    tagSystems: [
      for (final ts in m.tagSystems ?? const <TagSystem>[])
        TagSystemView(
          id: ts.id,
          name: ts.name,
          selectionMode: ts.selectionMode,
          isHierarchical: ts.isHierarchical,
          nodes: _tagNodesFromKgql(ts.nodes),
        ),
    ],
  );
}

String? _linkName(dynamic link) {
  if (link is String && link.isNotEmpty) return link;
  if (link is int) return link.toString();
  return null;
}

List<TagNodeView> _tagNodesFromKgql(List<TagNode> nodes) {
  return [
    for (final n in nodes)
      TagNodeView(
        name: n.name,
        children: n.children != null && n.children!.isNotEmpty
            ? _tagNodesFromKgql(n.children!)
            : null,
      ),
  ];
}
