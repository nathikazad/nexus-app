import 'package:nx_expense/domain/expense/related_model.dart';
import 'package:nx_expense/domain/expense/relation_edge.dart';
import 'package:nx_expense/domain/expense/expense_product_line.dart';

class Expense {
  const Expense({
    required this.id,
    required this.name,
    this.description,
    required this.modelTypeId,
    this.createdAt,
    this.attributes,
    this.relations,
    this.tags,
    this.relationsList,
    this.products = const [],
  });

  final int id;
  final String name;
  final String? description;
  final int modelTypeId;
  final String? createdAt;
  final Map<String, dynamic>? attributes;
  final Map<String, List<RelatedModel>>? relations;
  final Map<String, List<String>>? tags;
  final List<RelationEdge>? relationsList;
  final List<ExpenseProductLine> products;
}
