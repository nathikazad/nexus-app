import 'package:nx_db/kgql.dart';

import 'package:nx_expense/data/expense/expense_mapper.dart';
import 'package:nx_expense/domain/expense/related_model.dart';
import 'package:nx_expense/domain/transfer/transfer.dart';

Transfer transferFromModel(Model m) {
  Map<String, List<RelatedModel>>? rels;
  if (m.relations != null && m.relations!.isNotEmpty) {
    rels = {};
    for (final e in m.relations!.entries) {
      rels[e.key] = e.value.map(relatedModelFromModel).toList();
    }
  }
  Map<String, dynamic>? attrs;
  if (m.attributes != null) {
    attrs = Map<String, dynamic>.from(m.attributes!);
  }
  return Transfer(
    id: m.id,
    name: m.name,
    description: m.description,
    modelTypeId: m.modelTypeId,
    createdAt: m.createdAt,
    attributes: attrs,
    tags: m.tags == null
        ? null
        : m.tags!.map((k, v) => MapEntry(k, List<String>.from(v))),
    relations: rels,
    relationsList: relationEdgesFromModel(m),
  );
}
