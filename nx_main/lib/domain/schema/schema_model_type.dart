import 'attribute_definition_draft.dart';
import 'relation_definition_draft.dart';
import 'schema_tag_system_summary.dart';

/// Model type node for schema navigator UI (mirrors KGQL tree shape).
class SchemaModelType {
  final int id;
  final String name;
  final String? typeKind;
  final String? description;
  final int? parentId;
  final int? userId;
  final SchemaModelType? parent;
  final List<SchemaModelType>? children;
  final List<SchemaModelType>? traits;
  final List<AttributeDefinitionDraft>? attributes;
  final List<RelationDefinitionDraft>? relations;
  final List<SchemaTagSystemSummary>? tagSystems;

  const SchemaModelType({
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
    this.tagSystems,
  });

  SchemaModelType copyWith({
    int? id,
    String? name,
    String? typeKind,
    String? description,
    int? parentId,
    int? userId,
    SchemaModelType? parent,
    List<SchemaModelType>? children,
    List<SchemaModelType>? traits,
    List<AttributeDefinitionDraft>? attributes,
    List<RelationDefinitionDraft>? relations,
    List<SchemaTagSystemSummary>? tagSystems,
  }) {
    return SchemaModelType(
      id: id ?? this.id,
      name: name ?? this.name,
      typeKind: typeKind ?? this.typeKind,
      description: description ?? this.description,
      parentId: parentId ?? this.parentId,
      userId: userId ?? this.userId,
      parent: parent ?? this.parent,
      children: children ?? this.children,
      traits: traits ?? this.traits,
      attributes: attributes ?? this.attributes,
      relations: relations ?? this.relations,
      tagSystems: tagSystems ?? this.tagSystems,
    );
  }
}
