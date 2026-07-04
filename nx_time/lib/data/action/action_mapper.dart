import 'dart:developer' as developer;

import 'package:nx_db/kgql.dart';

import 'package:nx_time/core/debug_flags.dart';
import 'package:nx_time/core/time/wall_clock_time.dart';
import 'package:nx_time/domain/action/action.dart';
import 'package:nx_time/data/action/action_attr_keys.dart';

/// Notes from [Model.description] or top-level / attributes `description`.
String? notesDescriptionFromModel(Model model) {
  final top = model.description?.trim();
  if (top != null && top.isNotEmpty) return model.description;
  return model.attrString(kActionAttrDescription);
}

String? _actionEdgeRelationFromNestedModel(Model m) {
  final a = m.attributes?['relation'];
  if (a is String) return a;
  return null;
}

bool _nestedActionNeighborIsChild(Model c) {
  final rel = _actionEdgeRelationFromNestedModel(c);
  return rel == null || rel == 'child';
}

bool _isActionNeighborChild(Relation r) {
  if (r.modelType != kActionRelationKey &&
      r.modelType != kActionModelTypeName) {
    return false;
  }
  if (r.relation == 'parent') return false;
  if (r.relation == 'child') return true;
  return r.relation == null;
}

List<int> _childIdsFromModel(Model m) {
  final nested = m.relations?[kActionRelationKey];
  if (nested != null && nested.isNotEmpty) {
    final ids = nested
        .where(_nestedActionNeighborIsChild)
        .map((c) => c.id)
        .toList();
    if (kNxTimeTraceActionSemantics) {
      developer.log(
        '[nx_time action_map] id=${m.id} type=${m.modelType?.name} nested_Action_len=${nested.length} '
        'relationsList_len=${m.relationsList?.length ?? 0} → childIds from nested $ids',
        name: 'nx_time.action_map',
      );
    }
    return ids;
  }
  final list = m.relationsList;
  if (list == null || list.isEmpty) {
    if (kNxTimeTraceActionSemantics) {
      developer.log(
        '[nx_time action_map] id=${m.id} type=${m.modelType?.name} nested_Action empty '
        'relationsList_len=0 → childIds []',
        name: 'nx_time.action_map',
      );
    }
    return [];
  }
  final fromList = [
    for (final r in list)
      if (_isActionNeighborChild(r)) r.modelId,
  ];
  if (kNxTimeTraceActionSemantics) {
    final types = list.map((r) => '${r.modelType}:${r.modelId}').join(', ');
    developer.log(
      '[nx_time action_map] id=${m.id} type=${m.modelType?.name} nested_Action empty '
      'relationsList_len=${list.length} [$types] → childIds filtered $fromList',
      name: 'nx_time.action_map',
    );
  }
  return fromList;
}

Map<int, int> _relationIdsByChildFromModel(Model m) {
  final list = m.relationsList;
  if (list == null || list.isEmpty) return {};
  final out = <int, int>{};
  for (final r in list) {
    if (_isActionNeighborChild(r)) {
      out[r.modelId] = r.relationId;
    }
  }
  return out;
}

Action actionFromModel(Model m) {
  final start = m.attrDateTime(kActionAttrStartTime);
  final end = m.attrDateTime(kActionAttrEndTime);
  final childIds = _childIdsFromModel(m);
  return Action(
    id: m.id,
    name: m.name,
    description: notesDescriptionFromModel(m),
    modelTypeId: m.modelTypeId,
    modelTypeName: m.modelType?.name,
    startTime: start != null ? asStoredLocalWallClock(start) : null,
    endTime: end != null ? asStoredLocalWallClock(end) : null,
    childActionIds: childIds,
    relationIdByChildId: _relationIdsByChildFromModel(m),
  );
}

SetModelRequest setModelRequestForCreate(Action action, String modelTypeName) {
  final start = action.startTime;
  final end = action.endTime;
  if (start == null || end == null) {
    throw ArgumentError(
      'Action requires startTime and endTime for set_kgql_models',
    );
  }

  return SetModelRequest(
    modelType: modelTypeName,
    name: action.name.trim().isEmpty ? null : action.name,
    description: action.description,
    attributes: [
      SetModelAttribute(
        key: kActionAttrStartTime,
        value: start.toIso8601String(),
      ),
      SetModelAttribute(key: kActionAttrEndTime, value: end.toIso8601String()),
    ],
  );
}

/// Create and link the new row to an existing parent [Action] via `action_action`.
SetModelRequest setModelRequestForCreateWithParent(
  Action action,
  String modelTypeName, {
  required int parentActionId,
}) {
  final base = setModelRequestForCreate(action, modelTypeName);
  return SetModelRequest(
    modelType: base.modelType,
    name: base.name,
    description: base.description,
    attributes: base.attributes,
    relations: [
      ModelRelation(modelType: kActionRelationKey, link: [parentActionId]),
    ],
  );
}

SetModelRequest setModelRequestForUpdate(
  Action action, {
  String? modelTypeNameIfChanged,
}) {
  final start = action.startTime;
  final end = action.endTime;
  if (start == null || end == null) {
    throw ArgumentError(
      'Action requires startTime and endTime for set_kgql_models',
    );
  }

  return setKgqlUpdate(
    id: action.id,
    modelType: modelTypeNameIfChanged,
    name: action.name,
    description: action.description,
    attributes: [
      SetModelAttribute(
        key: kActionAttrStartTime,
        value: start.toIso8601String(),
      ),
      SetModelAttribute(key: kActionAttrEndTime, value: end.toIso8601String()),
    ],
  );
}

SetModelRequest setModelRequestForDelete(int id) => setKgqlDelete(id);
