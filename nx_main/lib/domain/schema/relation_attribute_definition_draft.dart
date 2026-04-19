/// Relation attribute definition for model-type create/edit (pure Dart).
class RelationAttributeDefinitionDraft {
  final int? id;
  final String key;
  final String valueType;
  final bool required;

  const RelationAttributeDefinitionDraft({
    this.id,
    required this.key,
    required this.valueType,
    this.required = false,
  });
}
