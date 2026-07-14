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

  /// Top-level `models.suggestion` JSON payload (optional).
  final Map<String, dynamic>? suggestion;

  /// Top-level `models.meta` JSON payload (optional).
  final Map<String, dynamic>? meta;

  /// Attributes array (optional)
  final List<SetModelAttribute>? attributes;

  /// Relations array (optional)
  final List<ModelRelation>? relations;

  /// Traits array (optional)
  final List<String>? traits;

  /// Tag assignments for `set_kgql_models` (optional).
  final List<SetModelTag>? tags;

  /// When true, deletes the model ([id] required). Other fields ignored.
  final bool delete;

  SetModelRequest({
    this.id,
    this.modelType,
    this.name,
    this.description,
    this.suggestion,
    this.meta,
    this.attributes,
    this.relations,
    this.traits,
    this.tags,
    this.delete = false,
  });

  /// Converts to JSON map for GraphQL mutation
  Map<String, dynamic> toJson() {
    if (delete) {
      if (id == null) {
        throw Exception('delete requires id');
      }
      return {'id': id, 'delete': true};
    }

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

    if (suggestion != null) {
      json['suggestion'] = suggestion;
    }

    if (meta != null) {
      json['meta'] = meta;
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

    if (tags != null) {
      json['tags'] = tags!.map((t) => t.toJson()).toList();
    }

    return json;
  }
}

/// Tag payload for `set_kgql_models` → `tags` array.
class SetModelTag {
  final String system;
  final List<String> nodes;
  final bool clear;

  SetModelTag({
    required this.system,
    required this.nodes,
    this.clear = false,
  });

  Map<String, dynamic> toJson() => {
        'system': system,
        'nodes': nodes,
        if (clear) 'clear': true,
      };
}

/// Attribute entry for `set_kgql_models` (write path).
///
/// Distinct from [ModelAttribute] in `attribute.dart` (read path from API responses).
class SetModelAttribute {
  final String key;
  final dynamic value;
  final bool delete;

  SetModelAttribute({
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
  final int? id;
  final String? modelType;
  final String? relationName;
  final List<dynamic>? link;
  final dynamic create;
  final bool delete;
  final List<RelationAttribute>? attributes;

  ModelRelation({
    this.id,
    this.modelType,
    this.relationName,
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
      return json;
    }

    if (modelType != null) {
      json['model_type'] = modelType;
    }

    if (relationName != null) {
      json['relation_name'] = relationName;
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
  final String key;
  final dynamic value;
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
