/// Model class representing a Model from the GraphQL API
/// Supports structure from get_kgql_models
class Model {
  final int id;
  final String name;
  final String? description;
  final int modelTypeId;
  final String? createdAt;
  final String? updatedAt;
  
  // Attributes from get_kgql_models (can be flat key-value pairs or attributes node)
  final Map<String, dynamic>? attributes;
  final List<ModelAttribute>? attributesList;
  
  // Relations from get_kgql_models (can be type-specific or general)
  final Map<String, List<Model>>? relations;
  final List<Relation>? relationsList;

  Model({
    required this.id,
    required this.name,
    this.description,
    required this.modelTypeId,
    this.createdAt,
    this.updatedAt,
    this.attributes,
    this.attributesList,
    this.relations,
    this.relationsList,
  });

  /// Creates a Model from a JSON map (typically from GraphQL response)
  factory Model.fromJson(Map<String, dynamic> json) {
    // Parse attributes (can be flat key-value pairs or attributes node)
    Map<String, dynamic>? attributes;
    List<ModelAttribute>? attributesList;
    
    if (json['attributes'] != null) {
      if (json['attributes'] is List) {
        // Attributes node (array of attribute objects)
        final attributesJson = json['attributes'] as List;
        attributesList = attributesJson.map((attrJson) {
          if (attrJson is Map<String, dynamic>) {
            return ModelAttribute.fromJson(attrJson);
          }
          return null;
        }).whereType<ModelAttribute>().toList();
        
        // Also build a map for backward compatibility
        final attrMap = <String, dynamic>{};
        for (var attr in attributesList) {
          attrMap[attr.key] = attr.value;
        }
        if (attrMap.isNotEmpty) {
          attributes = attrMap;
        }
      } else if (json['attributes'] is Map) {
        // Legacy format: attributes as a map
        attributes = Map<String, dynamic>.from(json['attributes'] as Map);
      }
    } else {
      // Check for individual attribute keys in the JSON (legacy format)
      final attrKeys = <String, dynamic>{};
      json.forEach((key, value) {
        // Skip known model fields
        if (!['id', 'name', 'description', 'model_type_id', 'created_at', 'updated_at', 'relations', 'attributes'].contains(key)) {
          // Check if it's not a relation (relations are capitalized and contain arrays of models)
          if (value is! List) {
            attrKeys[key] = value;
          } else {
            final list = value;
            if (list.isEmpty || (list.isNotEmpty && list[0] is! Map)) {
              attrKeys[key] = value;
            }
          }
        }
      });
      if (attrKeys.isNotEmpty) {
        attributes = attrKeys;
      }
    }
    
    // Parse relations
    Map<String, List<Model>>? relations;
    List<Relation>? relationsList;
    
    // Check for type-specific relations (capitalized keys like "Company", "Person")
    final typeSpecificRelations = <String, List<Model>>{};
    json.forEach((key, value) {
      // Relations are capitalized and contain arrays of Model objects
      if (key[0] == key[0].toUpperCase() && value is List) {
        final models = value.map((item) {
          if (item is Map<String, dynamic>) {
            return Model.fromJson(item);
          }
          return null;
        }).whereType<Model>().toList();
        if (models.isNotEmpty) {
          typeSpecificRelations[key] = models;
        }
      }
    });
    if (typeSpecificRelations.isNotEmpty) {
      relations = typeSpecificRelations;
    }
    
    // Check for general "relations" array
    final relationsJson = json['relations'];
    if (relationsJson != null && relationsJson is List) {
      relationsList = relationsJson.map((relJson) {
        if (relJson is Map<String, dynamic>) {
          return Relation.fromJson(relJson);
        }
        return null;
      }).whereType<Relation>().toList();
    }
    
    return Model(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      modelTypeId: json['model_type_id'] as int? ?? json['modelTypeId'] as int? ?? 0,
      createdAt: json['created_at'] as String? ?? json['createdAt'] as String?,
      updatedAt: json['updated_at'] as String? ?? json['updatedAt'] as String?,
      attributes: attributes,
      attributesList: attributesList,
      relations: relations,
      relationsList: relationsList,
    );
  }

  /// Converts a Model to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'modelTypeId': modelTypeId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      if (attributes != null) 'attributes': attributes,
      if (attributesList != null) 'attributes': attributesList!.map((a) => a.toJson()).toList(),
      if (relations != null) ...relations!,
      if (relationsList != null) 'relations': relationsList!.map((r) => r.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'Model(id: $id, name: $name, modelTypeId: $modelTypeId)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Model &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          modelTypeId == other.modelTypeId;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ modelTypeId.hashCode;

  /// Groups relations by model type (e.g., "Contact", "Place", "Company")
  /// Returns a map where keys are model type names and values are lists of Relation objects
  Map<String, List<Relation>> get relationsByModelType {
    if (relationsList == null || relationsList!.isEmpty) {
      return {};
    }

    final grouped = <String, List<Relation>>{};
    for (var relation in relationsList!) {
      final modelType = relation.modelType;
      grouped.putIfAbsent(modelType, () => []).add(relation);
    }
    return grouped;
  }
}

/// ModelAttribute object from get_kgql_models "attributes" array
class ModelAttribute {
  final int id;
  final String key;
  final String? value;

  ModelAttribute({
    required this.id,
    required this.key,
    this.value,
  });

  factory ModelAttribute.fromJson(Map<String, dynamic> json) {
    return ModelAttribute(
      id: json['id'] as int? ?? json['attribute_id'] as int? ?? 0,
      key: json['key'] as String? ?? '',
      value: json['value'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'key': key,
      if (value != null) 'value': value,
    };
  }
}

/// Relation object from get_kgql_models "relations" array
class Relation {
  final int relationId;
  final int modelId;
  final String modelType;
  final String? name;
  final String? description;

  Relation({
    required this.relationId,
    required this.modelId,
    required this.modelType,
    this.name,
    this.description,
  });

  factory Relation.fromJson(Map<String, dynamic> json) {
    return Relation(
      relationId: json['relation_id'] as int? ?? json['relationId'] as int? ?? json['id'] as int? ?? 0,
      modelId: json['model_id'] as int? ?? json['modelId'] as int? ?? 0,
      modelType: json['model_type'] as String? ?? json['modelType'] as String? ?? 'Unknown',
      name: json['name'] as String?,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'relation_id': relationId,
      'model_id': modelId,
      'model_type': modelType,
      'name': name,
      'description': description,
    };
  }
}

