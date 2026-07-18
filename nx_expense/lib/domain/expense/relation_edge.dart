/// One row from KGQL generic `relations` list on a model.
class RelationEdge {
  const RelationEdge({
    required this.relationId,
    required this.modelId,
    required this.modelType,
    this.name,
    this.description,
    this.relationAttributes,
  });

  final int relationId;
  final int modelId;
  final String modelType;
  final String? name;
  final String? description;
  final Map<String, dynamic>? relationAttributes;
}
