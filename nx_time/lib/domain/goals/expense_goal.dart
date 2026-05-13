import 'package:nx_time/domain/goals/goal_cadence.dart';
import 'package:nx_time/domain/goals/goal_threshold.dart';

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
  final GoalCadence cadence;
  final String modelType;
  final Map<String, dynamic>? filter;
  final String selectedAttribute;
  final String aggregation;
  final String? metric;
  final GoalTarget target;
  final num? periodValue;
}

class ExpenseGoalsMonth {
  const ExpenseGoalsMonth({required this.monthStart, required this.items});

  final DateTime monthStart;
  final List<ExpenseGoalMonthItem> items;
}
