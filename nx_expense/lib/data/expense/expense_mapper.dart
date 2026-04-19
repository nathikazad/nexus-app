import 'package:nx_db/kgql.dart';

import 'package:nx_expense/domain/expense/expense.dart';
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
    tags = {
      for (final e in m.tags!.entries) e.key: List<String>.from(e.value),
    };
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
  );
}
