import '../models/attribute.dart';
import '../models/relation.dart';

/// Model for creating or updating a model type using set_kgql_model_types.
///
/// This model matches the JSON structure expected by the set_kgql_model_types function.
/// See: servers/pgdb/docs/human-reference/set_kgql_model_types.md
class SetModelTypeRequest {
  final int? id;
  final String name;
  final String typeKind;
  final String? description;
  final ParentLink? parent;
  final List<AttributeDefinition>? attributeDefinitions;
  final List<RelationshipType>? relationshipTypes;
  final List<SetTagSystemRequest>? tagSystems;

  SetModelTypeRequest({
    this.id,
    required this.name,
    required this.typeKind,
    this.description,
    this.parent,
    this.attributeDefinitions,
    this.relationshipTypes,
    this.tagSystems,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'name': name,
      'type_kind': typeKind,
    };

    if (id != null) {
      json['id'] = id;
    }

    if (description != null) {
      json['description'] = description;
    }

    if (parent != null) {
      json['parent'] = parent!.toJson();
    }

    if (attributeDefinitions != null) {
      json['attribute_definitions'] =
          attributeDefinitions!.map((ad) => ad.toJson()).toList();
    }

    if (relationshipTypes != null) {
      json['relationship_types'] =
          relationshipTypes!.map((rt) => rt.toJson()).toList();
    }

    if (tagSystems != null) {
      json['tag_systems'] = tagSystems!.map((t) => t.toJson()).toList();
    }

    return json;
  }
}

/// Tag system payload for `set_kgql_model_types` → `tag_systems`.
class SetTagSystemRequest {
  final int? id;
  final String? name;
  final bool? isHierarchical;
  final String? selectionMode;
  final List<SetTagNodeRequest>? nodes;
  final bool delete;

  SetTagSystemRequest({
    this.id,
    this.name,
    this.isHierarchical,
    this.selectionMode,
    this.nodes,
    this.delete = false,
  });

  Map<String, dynamic> toJson() {
    if (delete) {
      if (id == null) {
        throw Exception('id is required when delete is true');
      }
      return {'id': id, 'delete': true};
    }
    final m = <String, dynamic>{};
    if (id != null) m['id'] = id;
    if (name != null) m['name'] = name;
    if (isHierarchical != null) m['is_hierarchical'] = isHierarchical;
    if (selectionMode != null) m['selection_mode'] = selectionMode;
    if (nodes != null) {
      m['nodes'] = nodes!.map((n) => n.toJson()).toList();
    }
    return m;
  }
}

class SetTagNodeRequest {
  final int? id;
  final String? name;
  final List<SetTagNodeRequest>? children;
  final bool delete;

  SetTagNodeRequest({
    this.id,
    this.name,
    this.children,
    this.delete = false,
  });

  Map<String, dynamic> toJson() {
    if (delete) {
      if (id == null) {
        throw Exception('id is required when delete is true');
      }
      return {'id': id, 'delete': true};
    }
    if (name == null || name!.isEmpty) {
      throw Exception('name is required when delete is false');
    }
    return {
      if (id != null) 'id': id,
      'name': name,
      if (children != null && children!.isNotEmpty)
        'children': children!.map((c) => c.toJson()).toList(),
    };
  }
}

/// Parent link - can be an ID (int) or name (String)
class ParentLink {
  final dynamic link;

  ParentLink({required this.link});

  Map<String, dynamic> toJson() {
    return {'link': link};
  }

  factory ParentLink.fromId(int id) {
    return ParentLink(link: id);
  }

  factory ParentLink.fromName(String name) {
    return ParentLink(link: name);
  }
}
