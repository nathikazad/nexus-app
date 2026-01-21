/// Model class representing a ModelType from the GraphQL API
/// Supports nested structure from get_kgql_model_type (parent, children, traits)
class ModelType {
  final int id;
  final String name;
  final String? typeKind;
  final String? description;
  final int? parentId;
  final int? userId;
  
  // Nested structure from get_kgql_model_type
  final ModelType? parent;
  final List<ModelType>? children;
  final List<ModelType>? traits;

  // Attributes and relations from get_kgql_model_type
  final List<AttributeDefinition>? attributes;
  final List<RelationshipType>? relations;

  ModelType({
    required this.id,
    required this.name,
    this.typeKind,
    this.description,
    this.parentId,
    this.userId,
    this.parent,
    this.children,
    this.traits,
    this.attributes,
    this.relations,
  });

  /// Creates a ModelType from a JSON map (typically from GraphQL response)
  /// Handles both flat structure (from allModelTypes) and nested structure (from get_kgql_model_type)
  factory ModelType.fromJson(Map<String, dynamic> json, {bool recursive = false}) {
    // Parse parent if present (from get_kgql_model_type)
    ModelType? parent;
    if (json['parent'] != null) {
      final parentJson = json['parent'] as Map<String, dynamic>;
      if (parentJson['id'] != null) {
        parent = ModelType.fromJson({
          'id': parentJson['id'],
          'name': parentJson['name'],
          'typeKind': json['type_kind'],
        }, recursive: false); // Don't recurse into parent's parent/children
      }
    }
    
    // Parse children if present (from get_kgql_model_type)
    // Extract current model type's ID to set as parentId for children
    final currentId = json['id'] as int?;
    List<ModelType>? children;
    if (json['children'] != null) {
      final childrenJson = json['children'] as List<dynamic>;
      children = childrenJson.map((childJson) {
        // Create a copy of the child JSON and add parentId if not already present
        final childMap = Map<String, dynamic>.from(childJson as Map<String, dynamic>);
        if (currentId != null && !childMap.containsKey('parentId')) {
          childMap['parentId'] = currentId;
        }
        return ModelType.fromJson(childMap, recursive: recursive);
      }).toList();
    }
    
    // Parse traits if present (from get_kgql_model_type)
    // Extract current model type's ID to set as parentId for traits
    List<ModelType>? traits;
    if (json['traits'] != null) {
      final traitsJson = json['traits'] as List<dynamic>;
      traits = traitsJson.map((traitJson) {
        // Create a copy of the trait JSON and add parentId if not already present
        final traitMap = Map<String, dynamic>.from(traitJson as Map<String, dynamic>);
        if (currentId != null && !traitMap.containsKey('parentId')) {
          traitMap['parentId'] = currentId;
        }
        return ModelType.fromJson(traitMap, recursive: false); // Traits don't have nested children/traits
      }).toList();
    }
    
    // Extract type_kind (snake_case from get_kgql_model_type) or typeKind (camelCase from old API)
    final typeKind = json['type_kind'] as String? ?? json['typeKind'] as String?;
    
    // Parse attributes if present (from get_kgql_model_type)
    List<AttributeDefinition>? attributes;
    if (json['attributes'] != null) {
      final attributesJson = json['attributes'] as List<dynamic>;
      attributes = attributesJson.map((attrJson) {
        final attr = attrJson as Map<String, dynamic>;
        return AttributeDefinition(
          id: attr['id'] as int?,
          key: attr['key'] as String?,
          valueType: attr['value_type'] as String?,
          required: attr['required'] as bool? ?? false,
          constraints: attr['constraints'] as Map<String, dynamic>?,
        );
      }).toList();
    }
    
    // Parse relations if present (from get_kgql_model_type)
    List<RelationshipType>? relations;
    if (json['relations'] != null) {
      final relationsJson = json['relations'] as List<dynamic>;
      relations = relationsJson.map((relJson) {
        final rel = relJson as Map<String, dynamic>;
        final targetModelTypeName = rel['target_model_type'] as String?;
        if (targetModelTypeName == null) return null;
        
        // Parse relation attribute definitions
        final relationAttrsJson = rel['attributes'] as List<dynamic>?;
        final relationAttributeDefinitions = relationAttrsJson?.map((attrJson) {
          final attr = attrJson as Map<String, dynamic>;
          return RelationAttributeDefinition(
            id: attr['id'] as int?,
            key: attr['key'] as String,
            valueType: attr['value_type'] as String,
            required: attr['required'] as bool? ?? false,
          );
        }).toList();
        
        return RelationshipType(
          id: rel['id'] as int?,
          link: targetModelTypeName, // Use name as link (get_kgql_model_type doesn't provide target ID)
          multiplicity: null, // get_kgql_model_type doesn't provide multiplicity
          description: null, // get_kgql_model_type doesn't provide description
          relationAttributeDefinitions: relationAttributeDefinitions,
        );
      }).whereType<RelationshipType>().toList();
    }
    
    return ModelType(
      id: json['id'] as int,
      name: json['name'] as String,
      typeKind: typeKind,
      description: json['description'] as String?,
      parentId: json['parentId'] as int? ?? parent?.id,
      userId: json['userId'] as int?,
      parent: parent,
      children: children,
      traits: traits,
      attributes: attributes,
      relations: relations,
    );
  }

  /// Converts a ModelType to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'typeKind': typeKind,
      'description': description,
      'parentId': parentId,
      'userId': userId,
      if (parent != null) 'parent': parent!.toJson(),
      if (children != null) 'children': children!.map((c) => c.toJson()).toList(),
      if (traits != null) 'traits': traits!.map((t) => t.toJson()).toList(),
      if (attributes != null) 'attributes': attributes!.map((a) => a.toJson()).toList(),
      if (relations != null) 'relations': relations!.map((r) => r.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'ModelType(id: $id, name: $name, typeKind: $typeKind, description: $description, parentId: $parentId, userId: $userId, children: ${children?.length ?? 0}, traits: ${traits?.length ?? 0})';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelType &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          typeKind == other.typeKind &&
          description == other.description &&
          parentId == other.parentId &&
          userId == other.userId;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      typeKind.hashCode ^
      description.hashCode ^
      parentId.hashCode ^
      userId.hashCode;
}

/// Single attribute definition
class AttributeDefinition {
  /// Attribute definition ID (required for update/delete, omitted for create)
  final int? id;

  /// Attribute key (required for create/update)
  final String? key;

  /// Value type: 'string', 'number', 'datetime', 'boolean', or 'vector' (required for create)
  final String? valueType;

  /// Whether the attribute is required (defaults to false)
  final bool required;

  /// Optional constraints JSON object
  final Map<String, dynamic>? constraints;

  /// Delete flag (true to delete this attribute definition)
  final bool delete;

  AttributeDefinition({
    this.id,
    this.key,
    this.valueType,
    this.required = false,
    this.constraints,
    this.delete = false,
  });

  Map<String, dynamic> toJson() {
    // For delete operations, only need id and delete flag
    if (delete) {
      if (id == null) {
        throw Exception('id is required when delete is true');
      }
      return {
        'id': id,
        'delete': true,
      };
    }

    // For create/update operations
    final json = <String, dynamic>{};

    if (id != null) {
      json['id'] = id;
    }

    if (key != null) {
      json['key'] = key;
    }

    if (valueType != null) {
      json['value_type'] = valueType;
    }

    json['required'] = required;

    if (constraints != null) {
      json['constraints'] = constraints;
    }

    return json;
  }
}

/// Single relationship type
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
  /// Direct array format - no 'create' wrapper
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
    // For delete operations, only need id and delete flag
    if (delete) {
      if (id == null) {
        throw Exception('id is required when delete is true');
      }
      return {
        'id': id,
        'delete': true,
      };
    }

    // For create/update operations
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
      json['relation_attribute_definitions'] = relationAttributeDefinitions!.map((rad) => rad.toJson()).toList();
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
    
    // Include id if present (for update operations)
    if (id != null) {
      json['id'] = id;
    }
    
    return json;
  }
}

