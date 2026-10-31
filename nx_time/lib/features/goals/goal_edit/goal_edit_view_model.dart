import 'package:flutter/material.dart';

import 'package:nx_time/domain/goals/goal.dart';
import 'package:nx_time/domain/goals/goal_cadence.dart';
import 'package:nx_time/domain/goals/goal_selected_attribute.dart';
import 'package:nx_time/domain/goals/goal_threshold.dart';

/// Create vs edit, mirroring [ActionEditMode].
enum GoalEditMode { create, edit }

/// Form helpers for [GoalEditPage] (no Riverpod — pure logic).
class GoalEditViewModel {
  GoalEditViewModel._();

  /// When switching to weekly, drop time-only attributes.
  static GoalSelectedAttribute clampAttributeForCadence(
    GoalCadence c,
    GoalSelectedAttribute a,
  ) {
    if (c != GoalCadence.weekly) return a;
    if (a == GoalSelectedAttribute.startTime ||
        a == GoalSelectedAttribute.endTime) {
      return GoalSelectedAttribute.count;
    }
    return a;
  }

  static bool showDueDays({required GoalCadence cadence}) {
    return cadence == GoalCadence.daily;
  }

  static String? snackbarErrorForSave({
    required String label,
    required GoalSelectedAttribute attr,
    required double durationHours,
    required int count,
    required TimeOfDay timeOfDay,
    required GoalCadence cadence,
    required Set<int> dueDays,
  }) {
    final t = label.trim();
    if (t.isEmpty) {
      return 'Name is required';
    }
    if (attr == GoalSelectedAttribute.duration) {
      if (durationHours <= 0) {
        return 'Enter a positive duration in hours';
      }
    } else if (attr == GoalSelectedAttribute.count) {
      if (count < 1) {
        return 'Count must be at least 1';
      }
    } else {
      // time — always valid 0-1439
    }
    if (showDueDays(cadence: cadence) && dueDays.isEmpty) {
      {
        return 'Choose at least one due day';
      }
    }
    return null;
  }

  static Goal buildGoal({
    required int? id,
    Goal? original,
    required String label,
    required bool active,
    required GoalCadence cadence,
    required String actionModelTypeName,
    required GoalSelectedAttribute selectedAttribute,
    required GoalThresholdOp op,
    required double durationHours,
    required int count,
    required TimeOfDay timeOfDay,
    required Set<int> dueDays,
    Map<String, dynamic>? filter,
    String? startDate,
    String? endDate,
    int? scheduleId,
    List<Map<String, dynamic>> scheduleEntries = const [],
  }) {
    final timeMinutes = timeOfDay.hour * 60 + timeOfDay.minute;
    num value;
    if (selectedAttribute == GoalSelectedAttribute.duration) {
      value = durationHours;
    } else if (selectedAttribute == GoalSelectedAttribute.count) {
      value = count;
    } else {
      value = timeMinutes;
    }
    return Goal(
      id: id,
      routineId: original?.routineId,
      routineName: original?.routineName,
      routineGoalCount: original?.routineGoalCount ?? 1,
      evaluation: original?.evaluation ?? 'aggregate',
      conditionFilter: original?.conditionFilter,
      restrictions: original?.restrictions,
      startDate: startDate,
      endDate: endDate,
      scheduleId: scheduleId,
      scheduleEntries: scheduleEntries,
      label: label.trim(),
      active: active,
      cadence: cadence,
      actionModelTypeName: actionModelTypeName,
      selectedAttribute: selectedAttribute,
      op: op,
      thresholdValue: value,
      filter: filter,
      dueDays: dueDays.isEmpty ? <int>[] : (dueDays.toList()..sort()),
    );
  }

  static String? scheduleError(
    List<Map<String, dynamic>> entries,
    String? startDate,
    String? endDate,
  ) {
    if (startDate == null) return 'Routine start date is required';
    for (final date in [startDate, endDate]) {
      if (date != null &&
          (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
              DateTime.tryParse(date)?.toIso8601String().split('T').first !=
                  date)) {
        return 'Enter a valid YYYY-MM-DD date';
      }
    }
    if (endDate != null && startDate.compareTo(endDate) > 0) {
      return 'End date must not precede start date';
    }
    for (final e in entries) {
      if ((e['days'] as List).isEmpty) {
        return 'Choose at least one weekday for each window';
      }
      for (final key in ['start_time', 'end_time']) {
        if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(e[key] as String)) {
          return 'Enter times as HH:mm';
        }
      }
      int minutes(String t) {
        final p = t.split(':');
        return int.parse(p[0]) * 60 + int.parse(p[1]);
      }

      if (minutes(e['end_time']) + ((e['end_day_offset'] ?? 0) as int) * 1440 <=
          minutes(e['start_time'])) {
        return 'End must be after start; use next day for overnight windows';
      }
    }
    return null;
  }
}
