import 'attribute_definition_draft.dart';
import 'relation_definition_draft.dart';
import 'schema_model_type.dart';

/// Pure-Dart fields for model-type create/edit (no Flutter).
class ModelTypeFormFields {
  final String name;
  final String description;
  final String typeKind;
  final int? parentId;
  final String? parentName;
  final List<AttributeDefinitionDraft> attributeDefinitions;
  final List<RelationDefinitionDraft> relationshipTypes;

  const ModelTypeFormFields({
    required this.name,
    required this.description,
    required this.typeKind,
    this.parentId,
    this.parentName,
    this.attributeDefinitions = const [],
    this.relationshipTypes = const [],
  });

  factory ModelTypeFormFields.fromSchemaModelType(SchemaModelType data) {
    return ModelTypeFormFields(
      name: data.name,
      description: data.description ?? '',
      typeKind: data.typeKind ?? 'base',
      parentId: data.parentId,
      parentName: data.parentId != null && data.parent != null
          ? data.parent!.name
          : null,
      attributeDefinitions: List<AttributeDefinitionDraft>.from(
        data.attributes ?? const [],
      ),
      relationshipTypes: List<RelationDefinitionDraft>.from(
        data.relations ?? const [],
      ),
    );
  }
}
