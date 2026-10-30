import 'package:nx_db/kgql.dart';
import 'package:nx_time/domain/goals/goal_evaluation.dart';

class SchedulePlan {
  const SchedulePlan({
    required this.id,
    required this.name,
    required this.entries,
    this.goalId,
    this.startDate,
    this.endDate,
    this.domainName,
  });
  final int id;
  final String name;
  final List<Map<String, dynamic>> entries;
  final int? goalId;
  final DateTime? startDate, endDate;
  final String? domainName;
  factory SchedulePlan.fromModel(Model m, {String? domainName}) {
    final goals = m.relations?['Goal'] ?? <Model>[];
    if (goals.length > 1) throw StateError('Schedule has multiple goals');
    final goal = goals.isEmpty ? null : goals.single;
    final dates = goal == null ? m.attributes : goal.attributes;
    return SchedulePlan(
      id: m.id,
      name: m.name,
      goalId: goal?.id,
      domainName: domainName,
      entries: ((m.attributes?['entries'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      startDate: goalWallClock(dates?['start_date']),
      endDate: goalWallClock(dates?['end_date']),
    );
  }
  List<PlanWindow> onDay(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    if (startDate != null && day.isBefore(startDate!) ||
        endDate != null && day.isAfter(endDate!)) {
      return [];
    }
    const days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    final result = <PlanWindow>[];
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      if (!(e['days'] as List).contains(days[day.weekday - 1])) continue;
      DateTime clock(String key, int offset) {
        final parts = (e[key] as String).split(':');
        return DateTime(
          day.year,
          day.month,
          day.day + offset,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
      }

      result.add(
        PlanWindow(
          plan: this,
          index: i,
          start: clock('start_time', 0),
          end: clock('end_time', (e['end_day_offset'] as num?)?.toInt() ?? 0),
        ),
      );
    }
    return result;
  }
}

class PlanWindow {
  const PlanWindow({
    required this.plan,
    required this.index,
    required this.start,
    required this.end,
  });
  final SchedulePlan plan;
  final int index;
  final DateTime start, end;
}
