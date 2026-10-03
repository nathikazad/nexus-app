import 'package:nx_time/core/time/wall_clock_time.dart';

/// Calendar projection; original records and their identities remain authoritative.
class CalendarEntry {
  CalendarEntry({
    required this.id,
    required this.kind,
    required this.modelType,
    required this.name,
    this.description,
    this.start,
    this.end,
    this.attributes = const {},
    this.links = const [],
    this.attendance = const [],
  });
  final int id;
  final String kind, modelType, name;
  final String? description;
  final DateTime? start, end;
  final Map<String, dynamic> attributes;
  final List<Map<String, dynamic>> links;
  final List<CalendarEntry> attendance;
  String? get status =>
      (attributes['planning_status'] ?? attributes['status']) as String?;
  bool get isTask =>
      modelType == 'Task' || ['task', 'deadline', 'completion'].contains(kind);
  DateTime? time(String key) => parseTime(attributes[key]);
  static DateTime? parseTime(dynamic value) {
    final parsed = value == null ? null : DateTime.tryParse(value.toString());
    return parsed == null ? null : asStoredLocalWallClock(parsed);
  }

  factory CalendarEntry.fromJson(Map<String, dynamic> row) => CalendarEntry(
    id: (row['id'] as num).toInt(),
    kind: row['kind'] as String? ?? 'action',
    modelType: row['model_type'] as String,
    name: row['name'] as String? ?? '',
    description: row['description'] as String?,
    start: parseTime(row['start']),
    end: parseTime(row['end']),
    attributes: Map<String, dynamic>.from(row['attributes'] as Map? ?? {}),
    links: [
      for (final x in row['links'] as List? ?? [])
        Map<String, dynamic>.from(x as Map),
    ],
    attendance: [
      for (final x in row['attendance'] as List? ?? [])
        CalendarEntry.fromJson(Map<String, dynamic>.from(x as Map)),
    ],
  );
  bool occursOn(DateTime day) {
    final a = start;
    if (a == null) return false;
    final d = DateTime(day.year, day.month, day.day);
    final next = DateTime(day.year, day.month, day.day + 1);
    return a.isBefore(next) &&
        (end != null && end!.isAfter(a) ? end!.isAfter(d) : !a.isBefore(d));
  }
}

class CalendarFeed {
  const CalendarFeed({
    this.entries = const [],
    this.unscheduled = const [],
    this.currentTasks = const [],
  });
  final List<CalendarEntry> entries, unscheduled, currentTasks;
  factory CalendarFeed.fromJson(Map<String, dynamic> json) => CalendarFeed(
    entries: [
      for (final r in json['entries'] as List? ?? [])
        CalendarEntry.fromJson(Map<String, dynamic>.from(r as Map)),
    ],
    currentTasks: [
      for (final r in json['current_tasks'] as List? ?? [])
        CalendarEntry.fromJson(Map<String, dynamic>.from(r as Map)),
    ],
    unscheduled: [
      for (final r in json['unscheduled'] as List? ?? [])
        CalendarEntry.fromJson(Map<String, dynamic>.from(r as Map)),
    ],
  );
}

class CalendarGroup {
  CalendarGroup(this.entry, this.children);
  final CalendarEntry entry;
  final List<CalendarGroup> children;
  Iterable<CalendarEntry> get descendants sync* {
    for (final child in children) {
      yield child.entry;
      yield* child.descendants;
    }
  }
}

/// Preserve Action umbrella relationships without hiding cycles or shared children.
List<CalendarGroup> groupCalendarEntries(List<CalendarEntry> entries) {
  final actions = {
    for (final e in entries)
      if (e.kind == 'action') e.id: e,
  };
  final childIds = <int>{};
  List<int> children(CalendarEntry e) => e.kind != 'action'
      ? []
      : [
          for (final l in e.links)
            if (l['relation_name'] == 'action_action' &&
                actions.containsKey(l['id']))
              l['id'] as int,
        ];
  for (final e in entries) {
    childIds.addAll(children(e));
  }
  final seen = <int>{};
  CalendarGroup visit(CalendarEntry e) {
    if (e.kind == 'action') seen.add(e.id);
    return CalendarGroup(e, [
      for (final id in children(e))
        if (!seen.contains(id)) visit(actions[id]!),
    ]);
  }

  final result = <CalendarGroup>[];
  for (final e in entries) {
    if (e.kind != 'action' || !childIds.contains(e.id)) {
      result.add(visit(e));
    }
  }
  for (final e in entries) {
    if (e.kind == 'action' && !seen.contains(e.id)) {
      result.add(visit(e));
    }
  }
  return result;
}
