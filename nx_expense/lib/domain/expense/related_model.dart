/// Lightweight related model row (nested relation on Expense / Transfer).
class RelatedModel {
  const RelatedModel({
    required this.id,
    required this.name,
    this.description,
    this.createdAt,
    this.attributes,
    this.relations,
  });

  final int id;
  final String name;
  final String? description;
  final String? createdAt;
  final Map<String, dynamic>? attributes;
  final Map<String, List<RelatedModel>>? relations;
}
