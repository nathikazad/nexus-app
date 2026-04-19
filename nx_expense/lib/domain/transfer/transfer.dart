import 'package:nx_expense/domain/expense/related_model.dart';
import 'package:nx_expense/domain/expense/relation_edge.dart';

class Transfer {
  const Transfer({
    required this.id,
    required this.name,
    this.description,
    required this.modelTypeId,
    this.createdAt,
    this.attributes,
    this.tags,
    this.relations,
    this.relationsList,
  });

  final int id;
  final String name;
  final String? description;
  final int modelTypeId;
  final String? createdAt;
  final Map<String, dynamic>? attributes;
  final Map<String, List<String>>? tags;
  final Map<String, List<RelatedModel>>? relations;
  final List<RelationEdge>? relationsList;
}
