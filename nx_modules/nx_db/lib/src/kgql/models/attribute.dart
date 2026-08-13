import '../../core/json/json_coercion.dart';

/// Single attribute definition (schema / `set_kgql_model_types`).
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

/// ModelAttribute object from get_kgql_models "attributes" array (read path).
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
      value: parseOptionalStringField(json['value']),
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
