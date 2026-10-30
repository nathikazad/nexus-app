import '../../core/json/json_coercion.dart';

/// Relation object from get_kgql_models "relations" array
class Relation {
  final int relationId;
  final int modelId;
  final String modelType;
  final String? name;
  final String? description;
  final String? relationName;
  final String? relationDescription;

  /// For self-type edges only (`from_model_type_id == to_model_type_id`): `'parent'`
  /// or `'child'` relative to the fetched model. Null for cross-type relations.
  final String? relation;

  /// Flat key → value from `relation_attributes` on the `relations` struct node.
  final Map<String, dynamic>? relationAttributes;

  /// Selected attributes from the related card in native sync payloads.
  final Map<String, dynamic>? relatedAttributes;

  Relation({
    required this.relationId,
    required this.modelId,
    required this.modelType,
    this.name,
    this.description,
    this.relationName,
    this.relationDescription,
    this.relation,
    this.relationAttributes,
    this.relatedAttributes,
  });

  factory Relation.fromJson(Map<String, dynamic> json) {
    return Relation(
      relationId:
          json['relation_id'] as int? ??
          json['relationId'] as int? ??
          json['id'] as int? ??
          0,
      modelId: json['model_id'] as int? ?? json['modelId'] as int? ?? 0,
      modelType:
          json['model_type'] as String? ??
          json['modelType'] as String? ??
          'Unknown',
      name: parseOptionalStringField(json['name']),
      description: parseOptionalStringField(json['description']),
      relationName: parseOptionalStringField(
        json['relation_name'] ?? json['relationName'],
      ),
      relationDescription: parseOptionalStringField(
        json['relation_description'] ?? json['relationDescription'],
      ),
      relation: parseOptionalStringField(json['relation']),
      relationAttributes: _parseRelationAttributes(json),
      relatedAttributes: json['related_attributes'] is Map
          ? Map<String, dynamic>.from(json['related_attributes'] as Map)
          : null,
    );
  }

  static Map<String, dynamic>? _parseRelationAttributes(
    Map<String, dynamic> json,
  ) {
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
      if (relationName != null) 'relation_name': relationName,
      if (relationDescription != null)
        'relation_description': relationDescription,
      if (relation != null) 'relation': relation,
      if (relationAttributes != null) 'relation_attributes': relationAttributes,
      if (relatedAttributes != null) 'related_attributes': relatedAttributes,
    };
  }
}

/// A named role in a relationship. Count is the maximum per opposite record.
class RelationshipEndpoint {
  final Object type;
  final String count;
  const RelationshipEndpoint({required this.type, required this.count});

  factory RelationshipEndpoint.fromJson(Map<String, dynamic> json) {
    final endpoint = RelationshipEndpoint(
      type: json['type'] as Object,
      count: json['count'] as String,
    );
    endpoint.toJson();
    return endpoint;
  }
  Map<String, dynamic> toJson() {
    if ((type is! String && type is! int) ||
        (type is String && (type as String).trim().isEmpty) ||
        !const ['one', 'many'].contains(count)) {
      throw ArgumentError(
        'An endpoint needs a model type and a one/many count',
      );
    }
    return {'type': type, 'count': count};
  }
}

/// Definition metadata; distinct from individual [Relation] records.
class RelationshipType {
  final int? id;
  final dynamic link;
  final Map<String, RelationshipEndpoint> endpoints;

  /// Read metadata used to keep reverse/inherited definitions out of writes.
  final int? definingModelTypeId;
  final String? relationName;
  final String? description;
  final List<RelationAttributeDefinition>? relationAttributeDefinitions;
  final bool delete;

  /// Flat count update supported by KGQL schema tooling.
  final String? toEndpointCount;

  RelationshipType({
    this.id,
    this.link,
    this.endpoints = const {},
    this.definingModelTypeId,
    this.relationName,
    this.description,
    this.relationAttributeDefinitions,
    this.delete = false,
    this.toEndpointCount,
  });

  /// Null for self-relations: callers must choose an explicit role.
  MapEntry<String, RelationshipEndpoint>? get targetEndpoint {
    final matches = endpoints.entries
        .where((e) => e.value.type == link)
        .toList();
    return matches.length == 1 ? matches.single : null;
  }

  Map<String, dynamic> toJson() {
    if (delete) {
      if (id == null) throw ArgumentError('id is required when delete is true');
      return {'id': id, 'delete': true};
    }
    if (endpoints.isNotEmpty &&
        (endpoints.length != 2 ||
            endpoints.keys.any(
              (name) => !RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name),
            ))) {
      throw ArgumentError('Exactly two distinct named endpoints are required');
    }
    if (toEndpointCount != null &&
        !const ['one', 'many'].contains(toEndpointCount)) {
      throw ArgumentError('Endpoint count must be one or many');
    }
    return {
      if (id != null) 'id': id,
      if (link != null) 'link': link,
      if (endpoints.isNotEmpty)
        'endpoints': endpoints.map((k, v) => MapEntry(k, v.toJson())),
      if (toEndpointCount != null) 'to_endpoint_count': toEndpointCount,
      if (relationName != null) 'name': relationName,
      if (description != null) 'description': description,
      if (relationAttributeDefinitions != null)
        'relation_attribute_definitions': relationAttributeDefinitions!
            .map((a) => a.toJson())
            .toList(),
    };
  }

  factory RelationshipType.fromId(
    int targetModelTypeId, {
    Map<String, RelationshipEndpoint> endpoints = const {},
    String? toEndpointCount,
    String? relationName,
    String? description,
    List<RelationAttributeDefinition>? relationAttributeDefinitions,
  }) => RelationshipType(
    link: targetModelTypeId,
    endpoints: endpoints,
    toEndpointCount: toEndpointCount,
    relationName: relationName,
    description: description,
    relationAttributeDefinitions: relationAttributeDefinitions,
  );

  factory RelationshipType.fromName(
    String targetModelTypeName, {
    Map<String, RelationshipEndpoint> endpoints = const {},
    String? toEndpointCount,
    String? relationName,
    String? description,
    List<RelationAttributeDefinition>? relationAttributeDefinitions,
  }) => RelationshipType(
    link: targetModelTypeName,
    endpoints: endpoints,
    toEndpointCount: toEndpointCount,
    relationName: relationName,
    description: description,
    relationAttributeDefinitions: relationAttributeDefinitions,
  );
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
