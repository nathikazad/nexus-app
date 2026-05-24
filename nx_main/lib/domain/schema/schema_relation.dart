/// Relation edge from get_kgql_models (read path).
class SchemaRelation {
  final int relationId;
  final int modelId;
  final String modelType;
  final String? name;
  final String? description;
  final String? relation;
  final Map<String, dynamic>? relationAttributes;

  const SchemaRelation({
    required this.relationId,
    required this.modelId,
    required this.modelType,
    this.name,
    this.description,
    this.relation,
    this.relationAttributes,
  });
}
