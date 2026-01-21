import 'package:nexus_voice_assistant/models/ModelType.dart';

/// Model for creating or updating a model type using set_kgql_model_types.
/// 
/// This model matches the JSON structure expected by the set_kgql_model_types function.
/// See: servers/pgdb/docs/human-reference/set_kgql_model_types.md
class SetModelTypeRequest {
  /// Model type ID (required for update, omitted for create)
  final int? id;

  /// Model type name (required)
  final String name;

  /// Type kind: 'base', 'trait', or 'abstract' (required)
  final String typeKind;

  /// Optional description
  final String? description;

  /// Parent model type link (optional)
  /// Can link by ID (int) or by name (String)
  final ParentLink? parent;

  /// Attribute definitions array (optional)
  /// Direct array format - no 'create' wrapper
  final List<AttributeDefinition>? attributeDefinitions;

  /// Relationship types array (optional)
  /// Direct array format - no 'create' wrapper
  final List<RelationshipType>? relationshipTypes;

  SetModelTypeRequest({
    this.id,
    required this.name,
    required this.typeKind,
    this.description,
    this.parent,
    this.attributeDefinitions,
    this.relationshipTypes,
  });

  /// Converts to JSON map for GraphQL mutation
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
      json['attribute_definitions'] = attributeDefinitions!.map((ad) => ad.toJson()).toList();
    }

    if (relationshipTypes != null) {
      json['relationship_types'] = relationshipTypes!.map((rt) => rt.toJson()).toList();
    }

    return json;
  }
}

/// Parent link - can be an ID (int) or name (String)
class ParentLink {
  /// Link value: either an integer ID or a String name
  final dynamic link; // int or String

  ParentLink({required this.link});

  Map<String, dynamic> toJson() {
    return {'link': link};
  }

  /// Create from integer ID
  factory ParentLink.fromId(int id) {
    return ParentLink(link: id);
  }

  /// Create from name
  factory ParentLink.fromName(String name) {
    return ParentLink(link: name);
  }
}