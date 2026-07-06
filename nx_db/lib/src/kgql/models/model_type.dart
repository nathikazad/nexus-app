import '../../core/json/json_coercion.dart';
import 'attribute.dart';
import 'relation.dart';
import 'tag_system.dart';

/// Model class representing a ModelType from the GraphQL API
/// Supports nested structure from get_kgql_model_type (parent, children, mixins)
class ModelType {
  final int id;
  final String name;
  final String? typeKind;
  final String? description;
  final Map<String, String>? agentInstructions;
  final int? parentId;
  final int? userId;

  final ModelType? parent;
  final List<ModelType>? children;
  final List<ModelType>? mixins;

  /// Legacy alias kept while older apps migrate from traits to type-level mixins.
  final List<ModelType>? traits;

  final List<AttributeDefinition>? attributes;
  final List<RelationshipType>? relations;

  /// Tag systems from `get_kgql_model_type` → `tag_systems` (null if not requested / absent).
  final List<TagSystem>? tagSystems;

  ModelType({
    required this.id,
    required this.name,
    this.typeKind,
    this.description,
    this.agentInstructions,
    this.parentId,
    this.userId,
    this.parent,
    this.children,
    List<ModelType>? mixins,
    List<ModelType>? traits,
    this.attributes,
    this.relations,
    this.tagSystems,
  })  : mixins = mixins ?? traits,
        traits = traits ?? mixins;

  /// Creates a ModelType from a JSON map (typically from GraphQL response)
  factory ModelType.fromJson(Map<String, dynamic> json,
      {bool recursive = false}) {
    ModelType? parent;
    if (json['parent'] != null) {
      final parentJson = json['parent'] as Map<String, dynamic>;
      if (parentJson['id'] != null) {
        parent = ModelType.fromJson({
          'id': parentJson['id'],
          'name': parentJson['name'],
          'type_kind': json['type_kind'],
        }, recursive: false);
      }
    }

    final currentId = jsonIntNullable(json['id']);
    List<ModelType>? children;
    if (json['children'] != null) {
      final childrenJson = json['children'] as List<dynamic>;
      children = childrenJson.map((childJson) {
        final childMap =
            Map<String, dynamic>.from(childJson as Map<String, dynamic>);
        if (currentId != null && !childMap.containsKey('parentId')) {
          childMap['parentId'] = currentId;
        }
        return ModelType.fromJson(childMap, recursive: recursive);
      }).toList();
    }

    List<ModelType>? mixins;
    final mixinsJson = json['mixins'] ?? json['traits'];
    if (mixinsJson != null) {
      final mixinRows = mixinsJson as List<dynamic>;
      mixins = mixinRows.map((mixinJson) {
        final traitMap =
            Map<String, dynamic>.from(mixinJson as Map<String, dynamic>);
        if (currentId != null && !traitMap.containsKey('parentId')) {
          traitMap['parentId'] = currentId;
        }
        return ModelType.fromJson(traitMap, recursive: false);
      }).toList();
    }

    final typeKind =
        json['type_kind'] as String? ?? json['typeKind'] as String?;
    final agentInstructionsJson =
        json['agent_instructions'] ?? json['agentInstructions'];
    final Map<String, String>? agentInstructions = agentInstructionsJson is Map
        ? agentInstructionsJson.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          )
        : null;

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

    List<RelationshipType>? relations;
    if (json['relations'] != null) {
      final relationsJson = json['relations'] as List<dynamic>;
      relations = relationsJson
          .map((relJson) {
            final rel = relJson as Map<String, dynamic>;
            final targetModelTypeName = rel['target_model_type'] as String?;
            if (targetModelTypeName == null) return null;

            final relationAttrsJson = rel['attributes'] as List<dynamic>?;
            final relationAttributeDefinitions =
                relationAttrsJson?.map((attrJson) {
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
              link: targetModelTypeName,
              multiplicity: rel['multiplicity'] as String? ??
                  rel['cardinality'] as String?,
              description: rel['description'] as String?,
              relationAttributeDefinitions: relationAttributeDefinitions,
            );
          })
          .whereType<RelationshipType>()
          .toList();
    }

    List<TagSystem>? tagSystems;
    final tagSystemsJson = json['tag_systems'] ?? json['tagSystems'];
    if (tagSystemsJson is List) {
      tagSystems = tagSystemsJson
          .map((e) => TagSystem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    return ModelType(
      id: modelJsonInt(json['id'], 0),
      name: json['name'] as String? ?? '',
      typeKind: typeKind,
      description: json['description'] as String?,
      agentInstructions: agentInstructions,
      parentId: json['parentId'] as int? ?? parent?.id,
      userId: json['userId'] as int?,
      parent: parent,
      children: children,
      mixins: mixins,
      traits: mixins,
      attributes: attributes,
      relations: relations,
      tagSystems: tagSystems,
    );
  }

  /// Converts a ModelType to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'typeKind': typeKind,
      'description': description,
      if (agentInstructions != null) 'agent_instructions': agentInstructions,
      'parentId': parentId,
      'userId': userId,
      if (parent != null) 'parent': parent!.toJson(),
      if (children != null)
        'children': children!.map((c) => c.toJson()).toList(),
      if (mixins != null) 'mixins': mixins!.map((t) => t.toJson()).toList(),
      if (attributes != null)
        'attributes': attributes!.map((a) => a.toJson()).toList(),
      if (relations != null)
        'relations': relations!.map((r) => r.toJson()).toList(),
      if (tagSystems != null)
        'tag_systems': tagSystems!.map((t) => t.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'ModelType(id: $id, name: $name, typeKind: $typeKind, description: $description, agentInstructions: $agentInstructions, parentId: $parentId, userId: $userId, children: ${children?.length ?? 0}, mixins: ${mixins?.length ?? 0})';
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
          agentInstructions == other.agentInstructions &&
          parentId == other.parentId &&
          userId == other.userId;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      typeKind.hashCode ^
      description.hashCode ^
      agentInstructions.hashCode ^
      parentId.hashCode ^
      userId.hashCode;
}
