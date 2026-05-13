import '../../core/json/json_coercion.dart';

/// Relation object from get_kgql_models "relations" array
class Relation {
  final int relationId;
  final int modelId;
  final String modelType;
  final String? name;
  final String? description;

  /// For self-type edges only (`from_model_type_id == to_model_type_id`): `'parent'`
  /// or `'child'` relative to the fetched model. Null for cross-type relations.
  final String? relation;

  /// Flat key → value from `relation_attributes` on the `relations` struct node.
  final Map<String, dynamic>? relationAttributes;

  Relation({
    required this.relationId,
    required this.modelId,
    required this.modelType,
    this.name,
    this.description,
    this.relation,
    this.relationAttributes,
  });

  factory Relation.fromJson(Map<String, dynamic> json) {
    return Relation(
      relationId: json['relation_id'] as int? ??
          json['relationId'] as int? ??
          json['id'] as int? ??
          0,
      modelId: json['model_id'] as int? ?? json['modelId'] as int? ?? 0,
      modelType: json['model_type'] as String? ??
          json['modelType'] as String? ??
          'Unknown',
      name: parseOptionalStringField(json['name']),
      description: parseOptionalStringField(json['description']),
      relation: parseOptionalStringField(json['relation']),
      relationAttributes: _parseRelationAttributes(json),
    );
  }

  static Map<String, dynamic>? _parseRelationAttributes(
      Map<String, dynamic> json) {
    final raw = json['relation_attributes'] ?? json['relationAttributes'];
    if (raw == null) {
      return null;
    }
    if (raw is! List) {
      return null;
    }
    final out = <String, dynamic>{};
    for (final e in raw) {
      if (e is! Map) {
        continue;
      }
      final m = Map<String, dynamic>.from(e);
      final key = m['key']?.toString();
      if (key == null || key.isEmpty) {
        continue;
      }
      if (m.containsKey('value')) {
        out[key] = m['value'];
      }
    }
    return out.isEmpty ? null : out;
  }

  Map<String, dynamic> toJson() {
    return {
      'relation_id': relationId,
      'model_id': modelId,
      'model_type': modelType,
      'name': name,
      'description': description,
      if (relation != null) 'relation': relation,
      if (relationAttributes != null) 'relation_attributes': relationAttributes,
    };
  }
}

/// Single relationship type (schema / `set_kgql_model_types`).
class RelationshipType {
  /// Relationship type ID (required for update/delete, omitted for create)
  final int? id;

  /// Link to target model type: either an integer ID or a String name (required for create)
  final dynamic link; // int or String

  /// Multiplicity: defaults to 'many'
  final String? multiplicity;

  /// Optional description
  final String? description;

  /// Relation attribute definitions array (optional)
  final List<RelationAttributeDefinition>? relationAttributeDefinitions;

  /// Delete flag (true to delete this relationship type)
  final bool delete;

  RelationshipType({
    this.id,
    this.link,
    this.multiplicity,
    this.description,
    this.relationAttributeDefinitions,
    this.delete = false,
  });

  Map<String, dynamic> toJson() {
    if (delete) {
      if (id == null) {
        throw Exception('id is required when delete is true');
      }
      return {
        'id': id,
        'delete': true,
      };
    }

    final json = <String, dynamic>{};

    if (id != null) {
      json['id'] = id;
    }

    if (link != null) {
      json['link'] = link;
    }

    if (multiplicity != null) {
      json['multiplicity'] = multiplicity;
    }

    if (description != null) {
      json['description'] = description;
    }

    if (relationAttributeDefinitions != null) {
      json['relation_attribute_definitions'] =
          relationAttributeDefinitions!.map((rad) => rad.toJson()).toList();
    }

    return json;
  }

  /// Create with integer ID link
  factory RelationshipType.fromId(
    int targetModelTypeId, {
    String? multiplicity,
    String? description,
    List<RelationAttributeDefinition>? relationAttributeDefinitions,
  }) {
    return RelationshipType(
      link: targetModelTypeId,
      multiplicity: multiplicity,
      description: description,
      relationAttributeDefinitions: relationAttributeDefinitions,
      delete: false,
    );
  }

  /// Create with name link
  factory RelationshipType.fromName(
    String targetModelTypeName, {
    String? multiplicity,
    String? description,
    List<RelationAttributeDefinition>? relationAttributeDefinitions,
  }) {
    return RelationshipType(
      link: targetModelTypeName,
      multiplicity: multiplicity,
      description: description,
      relationAttributeDefinitions: relationAttributeDefinitions,
      delete: false,
    );
  }
}

/// Single relation attribute definition
class RelationAttributeDefinition {
  /// Relation attribute definition ID (required for update/delete, omitted for create)
  final int? id;

  /// Attribute key (required)
  final String key;

  /// Value type: 'string', 'number', 'datetime', 'boolean', or 'vector' (required)
  final String valueType;

  /// Whether the attribute is required (defaults to false)
  final bool required;

  RelationAttributeDefinition({
    this.id,
    required this.key,
    required this.valueType,
    this.required = false,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'key': key,
      'value_type': valueType,
      'required': required,
    };

    if (id != null) {
      json['id'] = id;
    }

    return json;
  }
}
