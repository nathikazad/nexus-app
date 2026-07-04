import '../goal_parsing.dart';
import 'action_goal_week.dart';

class ActionGoalMonthResponse {
  const ActionGoalMonthResponse({
    required this.monthStart,
    required this.items,
  });

  final DateTime monthStart;
  final List<ActionGoalWeekItem> items;

  factory ActionGoalMonthResponse.fromJson(Map<String, dynamic> json) {
    final ms = parseDateOnly(json['month_start']);
    if (ms == null) {
      throw FormatException('ActionGoalMonthResponse: missing month_start');
    }
    final itemsJson = json['items'] as List<dynamic>?;
    final items = (itemsJson ?? const [])
        .map((e) {
          if (e is Map<String, dynamic>) {
            return ActionGoalWeekItem.fromJson(e);
          }
          if (e is Map) {
            return ActionGoalWeekItem.fromJson(Map<String, dynamic>.from(e));
          }
          return null;
        })
        .whereType<ActionGoalWeekItem>()
        .toList();
    return ActionGoalMonthResponse(monthStart: ms, items: items);
  }

  factory ActionGoalMonthResponse.emptyForMonth(DateTime monthStart) {
    return ActionGoalMonthResponse(monthStart: monthStart, items: const []);
  }

  Map<String, dynamic> toJson() => {
        'month_start': monthStart.toIso8601String().split('T').first,
        'items': items.map((e) => e.toJson()).toList(),
      };
}
