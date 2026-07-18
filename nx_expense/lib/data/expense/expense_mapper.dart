import 'package:nx_db/kgql.dart';

import 'package:nx_expense/domain/expense/expense.dart';
import 'package:nx_expense/domain/expense/expense_product_line.dart';
import 'package:nx_expense/domain/expense/model_names.dart';
import 'package:nx_expense/domain/expense/related_model.dart';
import 'package:nx_expense/domain/expense/relation_edge.dart';

RelatedModel relatedModelFromModel(Model m) {
  Map<String, List<RelatedModel>>? rels;
  if (m.relations != null && m.relations!.isNotEmpty) {
    rels = {};
    for (final e in m.relations!.entries) {
      rels[e.key] = e.value.map(relatedModelFromModel).toList();
    }
  }
  return RelatedModel(
    id: m.id,
    name: m.name,
    description: m.description,
    createdAt: m.createdAt,
    attributes: m.attributes != null
        ? Map<String, dynamic>.from(m.attributes!)
        : null,
    relations: rels,
  );
}

List<RelationEdge>? relationEdgesFromModel(Model m) {
  final list = m.relationsList;
  if (list == null || list.isEmpty) return null;
  return [
    for (final r in list)
      RelationEdge(
        relationId: r.relationId,
        modelId: r.modelId,
        modelType: r.modelType,
        name: r.name,
        description: r.description,
        relationAttributes: r.relationAttributes == null
            ? null
            : Map<String, dynamic>.from(r.relationAttributes!),
      ),
  ];
}

Expense expenseFromModel(Model m) {
  Map<String, List<RelatedModel>>? rels;
  if (m.relations != null && m.relations!.isNotEmpty) {
    rels = {};
    for (final e in m.relations!.entries) {
      rels[e.key] = e.value.map(relatedModelFromModel).toList();
    }
  }
  Map<String, List<String>>? tags;
  if (m.tags != null) {
    tags = {for (final e in m.tags!.entries) e.key: List<String>.from(e.value)};
  }
  Map<String, dynamic>? attrs;
  if (m.attributes != null) {
    attrs = Map<String, dynamic>.from(m.attributes!);
  }
  return Expense(
    id: m.id,
    name: m.name,
    description: m.description,
    modelTypeId: m.modelTypeId,
    createdAt: m.createdAt,
    attributes: attrs,
    relations: rels,
    tags: tags,
    relationsList: relationEdgesFromModel(m),
    products: _expenseProductsFromModel(m),
  );
}

List<ExpenseProductLine> _expenseProductsFromModel(Model expense) {
  final products = expense.relations?[kProductModelTypeName] ?? const <Model>[];
  final edges = expense.relationsList ?? const <Relation>[];
  return [
    for (final product in products)
      _expenseProductFromModel(
        product,
        edges.where(
          (edge) =>
              edge.modelType == kProductModelTypeName &&
              edge.modelId == product.id,
        ),
      ),
  ];
}

ExpenseProductLine _expenseProductFromModel(
  Model product,
  Iterable<Relation> edges,
) {
  final edge = edges.isEmpty ? null : edges.first;
  final productAttrs = product.attributes ?? const <String, dynamic>{};
  final relationAttrs = edge?.relationAttributes ?? const <String, dynamic>{};
  return ExpenseProductLine(
    id: product.id,
    name: product.name,
    brand: _textValue(productAttrs['brand']),
    imageUrl: _textValue(productAttrs['image_url']),
    itemUrl: _textValue(productAttrs['item_url']),
    price: _numberValue(relationAttrs['price']),
    quantity: _numberValue(relationAttrs['quantity']),
    unit: _textValue(relationAttrs['unit']),
  );
}

String? _textValue(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

num? _numberValue(dynamic value) {
  if (value is num) return value;
  return value == null ? null : num.tryParse(value.toString().trim());
}
