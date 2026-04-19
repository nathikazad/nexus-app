/// Attribute definition row for model-type create/edit (pure Dart).
class AttributeDefinitionDraft {
  final int? id;
  final String? key;
  final String? valueType;
  final bool required;
  final Map<String, dynamic>? constraints;
  final bool delete;

  const AttributeDefinitionDraft({
    this.id,
    this.key,
    this.valueType,
    this.required = false,
    this.constraints,
    this.delete = false,
  });
}
