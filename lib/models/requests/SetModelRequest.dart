/// Model for creating or updating a model using set_kgql_models.
/// 
/// This model matches the JSON structure expected by the set_kgql_models function.
/// See: servers/pgdb/docs/human-reference/set_kgql_models.md
class SetModelRequest {
  /// Model ID (required for update, omitted for create)
  final int? id;

  /// Model type name (required for create, optional for update)
  final String? modelType;

  /// Model name (required for create)
  final String? name;

  /// Optional description
  final String? description;

  /// Attributes array (optional)
  /// Each attribute can have:
  /// - key + value (create/update)
  /// - key + delete: true (delete)
  final List<ModelAttribute>? attributes;

  /// Relations array (optional)
  /// Each relation can be:
  /// - model_type + link (array of IDs or names)
  /// - model_type + create (object or array)
  /// - id + delete: true (delete)
  /// - id + attributes (update relation attributes)
  final List<ModelRelation>? relations;

  /// Traits array (optional)
  /// Array of trait names to assign to the model
  final List<String>? traits;

  SetModelRequest({
    this.id,
    this.modelType,
    this.name,
    this.description,
    this.attributes,
    this.relations,
    this.traits,
  });

  /// Converts to JSON map for GraphQL mutation
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (id != null) {
      json['id'] = id;
    }

    if (modelType != null) {
      json['model_type'] = modelType;
    }

    if (name != null) {
      json['name'] = name;
    }

    if (description != null) {
      json['description'] = description;
    }

    if (attributes != null) {
      json['attributes'] = attributes!.map((attr) => attr.toJson()).toList();
    }

    if (relations != null) {
      json['relations'] = relations!.map((rel) => rel.toJson()).toList();
    }

    if (traits != null) {
      json['traits'] = traits;
    }

    return json;
  }
}

/// Model attribute for create/update/delete operations
class ModelAttribute {
  /// Attribute key (required)
  final String key;

  /// Attribute value (for create/update)
  final dynamic value;

  /// Delete flag (for delete operations)
  final bool delete;

  ModelAttribute({
    required this.key,
    this.value,
    this.delete = false,
  });

  Map<String, dynamic> toJson() {
    if (delete) {
      return {
        'key': key,
        'delete': true,
      };
    }
    return {
      'key': key,
      'value': value,
    };
  }
}

/// Model relation for create/update/delete operations
class ModelRelation {
  /// Relation ID (for update/delete)
  final int? id;

  /// Model type name (for create/link)
  final String? modelType;

  /// Link to existing models (array of IDs or names)
  final List<dynamic>? link;

  /// Create new related models (object or array)
  final dynamic create;

  /// Delete flag (for delete operations)
  final bool delete;

  /// Relation attributes (for relation attributes)
  final List<RelationAttribute>? attributes;

  ModelRelation({
    this.id,
    this.modelType,
    this.link,
    this.create,
    this.delete = false,
    this.attributes,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (id != null) {
      json['id'] = id;
    }

    if (delete) {
      json['delete'] = true;
      return json; // For delete, only return id and delete
    }

    if (modelType != null) {
      json['model_type'] = modelType;
    }

    if (link != null) {
      json['link'] = link;
    }

    if (create != null) {
      json['create'] = create;
    }

    if (attributes != null) {
      json['attributes'] = attributes!.map((attr) => attr.toJson()).toList();
    }

    return json;
  }
}

/// Relation attribute for create/update/delete operations
class RelationAttribute {
  /// Attribute key (required)
  final String key;

  /// Attribute value (for create/update)
  final dynamic value;

  /// Delete flag (for delete operations)
  final bool delete;

  RelationAttribute({
    required this.key,
    this.value,
    this.delete = false,
  });

  Map<String, dynamic> toJson() {
    if (delete) {
      return {
        'key': key,
        'delete': true,
      };
    }
    return {
      'key': key,
      'value': value,
    };
  }
}

