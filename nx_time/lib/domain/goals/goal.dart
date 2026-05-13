import 'package:nx_time/domain/goals/goal_cadence.dart';
import 'package:nx_time/domain/goals/goal_selected_attribute.dart';
import 'package:nx_time/domain/goals/goal_threshold.dart';

/// Editable [Goal] aggregate for create/update. Distinct from read-side
/// [ActionGoalWeekItem] in [action_goal.dart].
class Goal {
  const Goal({
    this.id,
    required this.label,
    this.active = true,
    required this.cadence,
    required this.actionModelTypeName,
    required this.selectedAttribute,
    required this.op,
    required this.thresholdValue,
    this.filter,
    this.preferredDays = const <int>[],
    this.preferredTime,
    this.autoGenerateTasks = false,
  });

  /// `null` on create, set after insert or when editing.
  final int? id;

  /// Display / model name
  final String label;

  final bool active;

  final GoalCadence cadence;

  /// `model_type` attribute — e.g. `"Sleep"`, `"Gym"`, must match a concrete
  /// action subtype in KGQL.
  final String actionModelTypeName;

  final GoalSelectedAttribute selectedAttribute;
  final GoalThresholdOp op;

  /// - **Count:** integer (sessions)
  /// - **Duration:** hours (fractional)
  /// - **Start/end time:** minutes from local midnight
  final num thresholdValue;

  /// Optional additional filters (e.g. tag filters) — pass-through to KGQL.
  final Map<String, dynamic>? filter;

  /// Preferred days `0=Mon` … `6=Sun` (weekly + count in UI only).
  final List<int> preferredDays;

  /// `HH:mm` local time, shared for all [preferredDays]; `null` = no time.
  final String? preferredTime;

  final bool autoGenerateTasks;

  factory Goal.draft() {
    return const Goal(
      label: '',
      active: true,
      cadence: GoalCadence.daily,
      actionModelTypeName: 'Sleep',
      selectedAttribute: GoalSelectedAttribute.duration,
      op: GoalThresholdOp.gte,
      thresholdValue: 8,
      filter: null,
      preferredDays: <int>[],
      preferredTime: null,
      autoGenerateTasks: false,
    );
  }

  Goal copyWith({
    int? id,
    String? label,
    bool? active,
    GoalCadence? cadence,
    String? actionModelTypeName,
    GoalSelectedAttribute? selectedAttribute,
    GoalThresholdOp? op,
    num? thresholdValue,
    Map<String, dynamic>? filter,
    bool clearFilter = false,
    List<int>? preferredDays,
    String? preferredTime,
    bool clearPreferredTime = false,
    bool? autoGenerateTasks,
  }) {
    return Goal(
      id: id ?? this.id,
      label: label ?? this.label,
      active: active ?? this.active,
      cadence: cadence ?? this.cadence,
      actionModelTypeName: actionModelTypeName ?? this.actionModelTypeName,
      selectedAttribute: selectedAttribute ?? this.selectedAttribute,
      op: op ?? this.op,
      thresholdValue: thresholdValue ?? this.thresholdValue,
      filter: clearFilter ? null : (filter ?? this.filter),
      preferredDays: preferredDays ?? this.preferredDays,
      preferredTime: clearPreferredTime
          ? null
          : (preferredTime ?? this.preferredTime),
      autoGenerateTasks: autoGenerateTasks ?? this.autoGenerateTasks,
    );
  }
}
