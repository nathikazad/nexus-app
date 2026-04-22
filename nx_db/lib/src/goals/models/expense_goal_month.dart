import '../goal_parsing.dart' show parseDateOnly, parseNumLoose, unwrapObjectField;
import 'goal_target.dart';

class ExpenseGoalMonthItem {
  const ExpenseGoalMonthItem({
    required this.id,
    required this.label,
    required this.cadence,
    required this.modelType,
    this.filter,
    required this.selectedAttribute,
    required this.aggregation,
    this.metric,
    required this.target,
    this.periodValue,
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
  final num? periodValue;

  static String? _metricFromJson(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return raw;
    return raw.toString();
  }

  factory ExpenseGoalMonthItem.fromJson(Map<String, dynamic> json) {
    return ExpenseGoalMonthItem(
      id: (json['id'] as num).toInt(),
      label: json['label'] as String? ?? '',
      cadence: json['cadence'] as String? ?? '',
      modelType: json['model_type'] as String? ?? '',
      filter: (json['filter'] as Map?)?.cast<String, dynamic>() ??
          unwrapObjectField(json['filter']),
      selectedAttribute: json['selected_attribute'] as String? ?? '',
      aggregation: json['aggregation'] as String? ?? '',
      metric: _metricFromJson(json['metric']),
      target: GoalTarget.fromJson(
        (json['target'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      periodValue: parseNumLoose(json['period_value']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'cadence': cadence,
        'model_type': modelType,
        if (filter != null) 'filter': filter,
        'selected_attribute': selectedAttribute,
        'aggregation': aggregation,
        if (metric != null) 'metric': metric,
        'target': target.toJson(),
        if (periodValue != null) 'period_value': periodValue,
      };
}

class ExpenseGoalMonthResponse {
  const ExpenseGoalMonthResponse({
    required this.monthStart,
    required this.items,
  });

  final DateTime monthStart;
  final List<ExpenseGoalMonthItem> items;

  factory ExpenseGoalMonthResponse.fromJson(Map<String, dynamic> json) {
    final ms = parseDateOnly(json['month_start']);
    if (ms == null) {
      throw FormatException('ExpenseGoalMonthResponse: missing month_start');
    }
    final itemsJson = json['items'] as List<dynamic>?;
    final items = (itemsJson ?? const [])
        .map((e) {
          if (e is Map<String, dynamic>) {
            return ExpenseGoalMonthItem.fromJson(e);
          }
          if (e is Map) {
            return ExpenseGoalMonthItem.fromJson(Map<String, dynamic>.from(e));
          }
          return null;
        })
        .whereType<ExpenseGoalMonthItem>()
        .toList();
    return ExpenseGoalMonthResponse(monthStart: ms, items: items);
  }

  factory ExpenseGoalMonthResponse.emptyForMonth(DateTime monthStart) {
    return ExpenseGoalMonthResponse(monthStart: monthStart, items: const []);
  }

  Map<String, dynamic> toJson() => {
        'month_start': monthStart.toIso8601String().split('T').first,
        'items': items.map((e) => e.toJson()).toList(),
      };
}
