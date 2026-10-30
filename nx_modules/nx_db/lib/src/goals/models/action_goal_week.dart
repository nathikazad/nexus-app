import '../goal_parsing.dart';
import 'action_goal_schedule.dart';
import 'goal_daily_state.dart';
import 'goal_streak.dart';
import 'goal_target.dart';

class ActionGoalWeekItem {
  const ActionGoalWeekItem({
    required this.id,
    required this.label,
    required this.cadence,
    required this.modelType,
    this.filter,
    required this.selectedAttribute,
    required this.aggregation,
    this.metric,
    required this.target,
    required this.dailyState,
    required this.streak,
    this.schedule,
    this.evaluation = 'aggregate',
    this.restrictions,
  });

  final int id;
  final String label;
  final String cadence;
  final String modelType;
  final Map<String, dynamic>? filter;
  final String selectedAttribute;
  final String aggregation;
  final String? metric;
  final GoalTarget target;
  final List<GoalDailyState> dailyState;
  final GoalStreakSummary streak;
  final ActionGoalSchedule? schedule;
  final String evaluation;
  final Map<String, dynamic>? restrictions;

  static String? _metricFromJson(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return raw;
    return raw.toString();
  }

  factory ActionGoalWeekItem.fromJson(Map<String, dynamic> json) {
    final ds = json['daily_state'] as List<dynamic>?;
    return ActionGoalWeekItem(
      id: (json['id'] as num).toInt(),
      label: json['label'] as String? ?? '',
      cadence: json['cadence'] as String? ?? '',
      modelType: json['model_type'] as String? ?? '',
      filter:
          (json['filter'] as Map?)?.cast<String, dynamic>() ??
          unwrapObjectField(json['filter']),
      selectedAttribute: json['selected_attribute'] as String? ?? '',
      aggregation: json['aggregation'] as String? ?? '',
      metric: _metricFromJson(json['metric']),
      target: GoalTarget.fromJson(
        (json['target'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      dailyState: (ds ?? const [])
          .map((e) {
            if (e is Map<String, dynamic>) {
              return GoalDailyState.fromJson(e);
            }
            if (e is Map) {
              return GoalDailyState.fromJson(Map<String, dynamic>.from(e));
            }
            return null;
          })
          .whereType<GoalDailyState>()
          .toList(),
      streak: GoalStreakSummary.fromJson(
        (json['streak'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      schedule: _scheduleFromJson(json['schedule']),
      evaluation: json['evaluation'] as String? ?? 'aggregate',
      restrictions: unwrapObjectField(json['restrictions']),
    );
  }

  static ActionGoalSchedule? _scheduleFromJson(dynamic raw) {
    if (raw == null) return null;
    final m = unwrapObjectField(raw);
    if (m == null) return null;
    return ActionGoalSchedule.fromJson(m);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'cadence': cadence,
    'evaluation': evaluation,
    if (restrictions != null) 'restrictions': restrictions,
    'model_type': modelType,
    if (filter != null) 'filter': filter,
    'selected_attribute': selectedAttribute,
    'aggregation': aggregation,
    if (metric != null) 'metric': metric,
    'target': target.toJson(),
    'daily_state': dailyState.map((e) => e.toJson()).toList(),
    'streak': streak.toJson(),
    if (schedule != null) 'schedule': schedule!.toJson(),
  };
}

class ActionGoalWeekResponse {
  const ActionGoalWeekResponse({required this.weekStart, required this.items});

  final DateTime weekStart;
  final List<ActionGoalWeekItem> items;

  factory ActionGoalWeekResponse.fromJson(Map<String, dynamic> json) {
    final ws = parseDateOnly(json['week_start']);
    if (ws == null) {
      throw FormatException('ActionGoalWeekResponse: missing week_start');
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
    return ActionGoalWeekResponse(weekStart: ws, items: items);
  }

  /// Empty response when the field is null (unauthenticated / no data).
  factory ActionGoalWeekResponse.emptyForWeek(DateTime weekStart) {
    return ActionGoalWeekResponse(weekStart: weekStart, items: const []);
  }

  Map<String, dynamic> toJson() => {
    'week_start': weekStart.toIso8601String().split('T').first,
    'items': items.map((e) => e.toJson()).toList(),
  };
}
