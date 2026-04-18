import 'package:nx_db/kgql.dart';

import 'package:nx_time/core/time/wall_clock_time.dart';
import 'package:nx_time/domain/action/action.dart';
import 'package:nx_time/data/action/action_attr_keys.dart';

/// Notes from [Model.description] or top-level / attributes `description`.
String? notesDescriptionFromModel(Model model) {
  final top = model.description?.trim();
  if (top != null && top.isNotEmpty) return model.description;
  return model.attrString(kActionAttrDescription);
}

Action actionFromModel(Model m) {
  final start = m.attrDateTime(kActionAttrStartTime);
  final end = m.attrDateTime(kActionAttrEndTime);
  return Action(
    id: m.id,
    name: m.name,
    description: notesDescriptionFromModel(m),
    modelTypeId: m.modelTypeId,
    modelTypeName: m.modelType?.name,
    startTime: start != null ? asStoredLocalWallClock(start) : null,
    endTime: end != null ? asStoredLocalWallClock(end) : null,
  );
}

SetModelRequest setModelRequestForCreate(Action action, String modelTypeName) {
  final start = action.startTime;
  final end = action.endTime;
  if (start == null || end == null) {
    throw ArgumentError('Action requires startTime and endTime for set_kgql_models');
  }

  return setKgqlCreate(
    modelType: modelTypeName,
    name: action.name,
    description: action.description,
    attributes: [
      SetModelAttribute(
        key: kActionAttrStartTime,
        value: start.toIso8601String(),
      ),
      SetModelAttribute(
        key: kActionAttrEndTime,
        value: end.toIso8601String(),
      ),
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
    throw ArgumentError('Action requires startTime and endTime for set_kgql_models');
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
      SetModelAttribute(
        key: kActionAttrEndTime,
        value: end.toIso8601String(),
      ),
    ],
  );
}

SetModelRequest setModelRequestForDelete(int id) => setKgqlDelete(id);
