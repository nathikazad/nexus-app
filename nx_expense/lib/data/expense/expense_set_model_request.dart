import 'package:flutter/foundation.dart' show setEquals;
import 'package:nx_db/kgql.dart';

import 'package:nx_expense/data/schema/kgql_schema_helpers.dart';
import 'package:nx_expense/domain/expense/expense_upsert.dart';
import 'package:nx_expense/domain/expense/model_names.dart';

String? _descOrNull(String? d) =>
    d == null || d.trim().isEmpty ? null : d.trim();

SetModelRequest buildExpenseSetModelRequest(ExpenseUpsert u) {
  final attrs = <SetModelAttribute>[
    for (final e in u.attributes.entries)
      SetModelAttribute(key: e.key, value: e.value),
  ];

  final tagPayload = <SetModelTag>[
    for (final e in u.tags.entries)
      SetModelTag(system: e.key, nodes: e.value, clear: e.value.isEmpty),
  ];

  final relPayload = <ModelRelation>[];
  final isUpdate = u.id != null;

  for (final e in u.relationsByType.entries) {
    final type = e.key;
    final create = u.relationCreatesByType[type];

    if (create != null && create.isNotEmpty) {
      relPayload.add(ModelRelation(modelType: type, create: [create]));
      continue;
    }

    final curIds = dedupeIntIdsPreserveOrder(e.value).toSet();
    final snapIds = u.snapshotLinkIdsByType[type] ?? <int>{};

    if (isUpdate) {
      if (setEquals(curIds, snapIds) &&
          relationPendingCreateEquals(
            u.relationCreatesByType[type],
            u.snapshotCreatesByType[type],
          )) {
        continue;
      }

      final removed = snapIds.difference(curIds);
      final edgeMap = u.relationEdgeIdsByType[type] ?? {};
      for (final modelId in removed) {
        final edgeId = edgeMap[modelId];
        if (edgeId != null) {
          relPayload.add(ModelRelation(id: edgeId, delete: true));
        }
      }

      final added = curIds.difference(snapIds);
      if (added.isNotEmpty) {
        relPayload.add(ModelRelation(modelType: type, link: added.toList()));
      }
    } else {
      if (curIds.isNotEmpty) {
        relPayload.add(ModelRelation(modelType: type, link: curIds.toList()));
      }
    }
  }

  return SetModelRequest(
    id: u.id,
    modelType: u.id == null ? kExpenseModelTypeName : null,
    name: u.name.trim(),
    description: _descOrNull(u.description),
    attributes: attrs.isEmpty ? null : attrs,
    tags: tagPayload.isEmpty ? null : tagPayload,
    relations: relPayload.isEmpty ? null : relPayload,
  );
}
