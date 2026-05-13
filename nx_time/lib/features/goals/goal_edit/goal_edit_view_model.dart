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

  /// `true` if weekly count UI should show preferred days + time + auto.
  static bool showPreferredSlots({
    required GoalCadence cadence,
    required GoalSelectedAttribute attr,
  }) {
    return cadence == GoalCadence.weekly && attr == GoalSelectedAttribute.count;
  }

  static String? snackbarErrorForSave({
    required String label,
    required GoalSelectedAttribute attr,
    required double durationHours,
    required int count,
    required TimeOfDay timeOfDay,
    required GoalCadence cadence,
    required bool autoCreate,
    required Set<int> preferredDays,
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
    if (showPreferredSlots(cadence: cadence, attr: attr) &&
        autoCreate &&
        preferredDays.isEmpty) {
      return 'Choose at least one preferred day to auto-create tasks, or turn auto-create off';
    }
    return null;
  }

  static Goal buildGoal({
    required int? id,
    required String label,
    required bool active,
    required GoalCadence cadence,
    required String actionModelTypeName,
    required GoalSelectedAttribute selectedAttribute,
    required GoalThresholdOp op,
    required double durationHours,
    required int count,
    required TimeOfDay timeOfDay,
    required Set<int> preferredDays,
    required String? preferredTimeHHmm,
    required bool autoGenerate,
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
      label: label.trim(),
      active: active,
      cadence: cadence,
      actionModelTypeName: actionModelTypeName,
      selectedAttribute: selectedAttribute,
      op: op,
      thresholdValue: value,
      filter: null,
      preferredDays: preferredDays.isEmpty
          ? <int>[]
          : (preferredDays.toList()..sort()),
      preferredTime: (preferredTimeHHmm == null || preferredTimeHHmm.isEmpty)
          ? null
          : preferredTimeHHmm,
      autoGenerateTasks: autoGenerate,
    );
  }
}
