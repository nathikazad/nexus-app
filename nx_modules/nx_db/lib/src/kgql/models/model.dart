import '../../core/json/json_coercion.dart';
import 'attribute.dart';
import 'model_type.dart';
import 'relation.dart';

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

  /// Tag assignments when `tags: true` is in struct — system name → assigned node names.
  final Map<String, List<String>>? tags;

  /// Embedded type metadata when `struct` includes a `model_type: { ... }` object (get_kgql_models).
  final ModelType? modelType;

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
    this.tags,
    this.modelType,
  });

  /// Creates a Model from a JSON map (typically from GraphQL response)
  factory Model.fromJson(Map<String, dynamic> json) {
    ModelType? embeddedModelType;
    final modelTypeJson = json['model_type'];
    if (modelTypeJson is Map<String, dynamic>) {
      embeddedModelType = ModelType.fromJson(modelTypeJson, recursive: true);
    }

    Map<String, dynamic>? attributes;
    List<ModelAttribute>? attributesList;

    if (json['attributes'] != null) {
      if (json['attributes'] is List) {
        final attributesJson = json['attributes'] as List;
        attributesList = attributesJson
            .map((attrJson) {
              if (attrJson is Map<String, dynamic>) {
                return ModelAttribute.fromJson(attrJson);
              }
              return null;
            })
            .whereType<ModelAttribute>()
            .toList();

        final attrMap = <String, dynamic>{};
        for (var attr in attributesList) {
          attrMap[attr.key] = attr.value;
        }
        if (attrMap.isNotEmpty) {
          attributes = attrMap;
        }
      } else if (json['attributes'] is Map) {
        attributes = Map<String, dynamic>.from(json['attributes'] as Map);
      }
    } else {
      final attrKeys = <String, dynamic>{};
      json.forEach((key, value) {
        if (![
          'id',
          'name',
          'description',
          'model_type_id',
          'created_at',
          'updated_at',
          'relations',
          'attributes',
          'tags',
          'model_type',
        ].contains(key)) {
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

    Map<String, List<Model>>? relations;
    List<Relation>? relationsList;

    final typeSpecificRelations = <String, List<Model>>{};
    json.forEach((key, value) {
      if (key[0] == key[0].toUpperCase() && value is List) {
        final models = value
            .map((item) {
              if (item is Map<String, dynamic>) {
                return Model.fromJson(item);
              }
              return null;
            })
            .whereType<Model>()
            .toList();
        if (models.isNotEmpty) {
          typeSpecificRelations[key] = models;
        }
      }
    });
    if (typeSpecificRelations.isNotEmpty) {
      relations = typeSpecificRelations;
    }

    final relationsJson = json['relations'];
    if (relationsJson != null && relationsJson is List) {
      relationsList = relationsJson
          .map((relJson) {
            if (relJson is Map<String, dynamic>) {
              return Relation.fromJson(relJson);
            }
            return null;
          })
          .whereType<Relation>()
          .toList();
    }

    Map<String, List<String>>? tags;
    final tagsJson = json['tags'];
    if (tagsJson is Map) {
      tags = tagsJson.map((k, v) {
        final key = k as String;
        if (v is List) {
          return MapEntry(key, v.map((e) => e.toString()).toList());
        }
        return MapEntry(key, <String>[]);
      });
    }

    return Model(
      id: modelJsonInt(json['id'], 0),
      name: json['name'] as String? ?? '',
      description: parseOptionalStringField(json['description']),
      modelTypeId: modelJsonInt(
        json['model_type_id'] ?? json['modelTypeId'],
        0,
      ),
      createdAt: json['created_at'] as String? ?? json['createdAt'] as String?,
      updatedAt: json['updated_at'] as String? ?? json['updatedAt'] as String?,
      attributes: attributes,
      attributesList: attributesList,
      relations: relations,
      relationsList: relationsList,
      tags: tags,
      modelType: embeddedModelType,
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
      if (attributesList != null)
        'attributes': attributesList!.map((a) => a.toJson()).toList(),
      if (relations != null) ...relations!,
      if (relationsList != null)
        'relations': relationsList!.map((r) => r.toJson()).toList(),
      if (tags != null) 'tags': tags,
      if (modelType != null) 'model_type': modelType!.toJson(),
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
