import 'package:nx_db/kgql.dart';

import 'package:nx_time/data/log/log_attr_keys.dart';
import 'package:nx_time/domain/log/daily_log.dart';

DailyLog dailyLogFromModel(Model m) {
  final loggedAt = m.attrDateTime(kDailyLogAttrLoggedAt);
  final entry = m.attrString(kDailyLogAttrEntry);
  final tags = m.tags == null
      ? null
      : {for (final e in m.tags!.entries) e.key: List<String>.from(e.value)};
  return DailyLog(
    id: m.id,
    modelTypeId: m.modelTypeId,
    loggedAt: loggedAt,
    entry: entry,
    tags: tags,
  );
}

SetModelRequest setModelRequestForCreateDailyLog({
  required DateTime loggedAt,
  String? entry,
  Map<String, List<String>> tags = const {},
}) {
  final attrs = <SetModelAttribute>[
    SetModelAttribute(
      key: kDailyLogAttrLoggedAt,
      value: loggedAt.toIso8601String(),
    ),
    if (entry != null && entry.trim().isNotEmpty)
      SetModelAttribute(key: kDailyLogAttrEntry, value: entry),
  ];
  return SetModelRequest(
    modelType: kDailyLogModelTypeName,
    name: _logName(loggedAt),
    attributes: attrs,
    tags: _setModelTags(tags, clearEmpty: false),
  );
}

SetModelRequest setModelRequestForUpdateDailyLog({
  required int id,
  required DateTime loggedAt,
  String? entry,
  Map<String, List<String>> tags = const {},
}) {
  final attrs = <SetModelAttribute>[
    SetModelAttribute(
      key: kDailyLogAttrLoggedAt,
      value: loggedAt.toIso8601String(),
    ),
    if (entry != null && entry.trim().isNotEmpty)
      SetModelAttribute(key: kDailyLogAttrEntry, value: entry)
    else
      SetModelAttribute(key: kDailyLogAttrEntry, delete: true),
  ];
  return SetModelRequest(
    id: id,
    name: _logName(loggedAt),
    attributes: attrs,
    tags: _setModelTags(tags, clearEmpty: true),
  );
}

SetModelRequest setModelRequestForDeleteDailyLog(int id) => setKgqlDelete(id);

String _logName(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'Log ${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

List<SetModelTag>? _setModelTags(
  Map<String, List<String>> tags, {
  required bool clearEmpty,
}) {
  if (tags.isEmpty) return null;
  final out = [
    for (final e in tags.entries)
      if (e.value.isNotEmpty || clearEmpty)
        SetModelTag(
          system: e.key,
          nodes: e.value,
          clear: clearEmpty && e.value.isEmpty,
        ),
  ];
  return out.isEmpty ? null : out;
}
