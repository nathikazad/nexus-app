import 'package:nx_db/nx_db.dart' hide ModelAttribute;
import 'package:nx_db/src/kgql/requests/set_model_request.dart' show ModelAttribute;

import 'package:nx_time/core/time/wall_clock_time.dart';
import 'package:nx_time/domain/action/action.dart';
import 'package:nx_time/data/action/action_attr_keys.dart';
import 'package:nx_time/data/action/kgql_model_wall_clock.dart';

/// Notes from [Model.description] or top-level / attributes `description`.
String? notesDescriptionFromModel(Model model) {
  final top = model.description?.trim();
  if (top != null && top.isNotEmpty) return model.description;
  final raw = model.attributes?[kActionAttrDescription];
  if (raw == null) return null;
  if (raw is String) {
    final t = raw.trim();
    return t.isEmpty ? null : t;
  }
  final s = raw.toString().trim();
  return s.isEmpty ? null : s;
}

Action actionFromModel(Model m) {
  final start = readWallClockDateTimeAttr(m, kActionAttrStartTime);
  final end = readWallClockDateTimeAttr(m, kActionAttrEndTime);
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

  return SetModelRequest(
    modelType: modelTypeName,
    name: action.name,
    description: action.description,
    attributes: [
      ModelAttribute(key: kActionAttrStartTime, value: start.toIso8601String()),
      ModelAttribute(key: kActionAttrEndTime, value: end.toIso8601String()),
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

  return SetModelRequest(
    id: action.id,
    modelType: modelTypeNameIfChanged,
    name: action.name,
    description: action.description,
    attributes: [
      ModelAttribute(key: kActionAttrStartTime, value: start.toIso8601String()),
      ModelAttribute(key: kActionAttrEndTime, value: end.toIso8601String()),
    ],
  );
}

SetModelRequest setModelRequestForDelete(int id) =>
    SetModelRequest(id: id, delete: true);
