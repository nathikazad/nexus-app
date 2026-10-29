import 'package:flutter/material.dart';
import 'package:nx_time/domain/goals/goal_threshold.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/domain/goals/goal_cadence.dart';
import 'package:nx_time/domain/goals/goal_selected_attribute.dart';
import 'package:nx_time/features/goals/goal_edit/goal_edit_view_model.dart';

void main() {
  test('editing an exercise goal preserves its type filter', () {
    final filter = <String, dynamic>{
      'filters': [
        {'key': 'type', 'op': '=', 'value': 'Yoga'},
      ],
    };
    final goal = GoalEditViewModel.buildGoal(
      id: 1,
      label: 'Yoga',
      active: true,
      cadence: GoalCadence.weekly,
      actionModelTypeName: 'Exercise',
      selectedAttribute: GoalSelectedAttribute.count,
      op: GoalThresholdOp.gte,
      durationHours: 0,
      count: 2,
      timeOfDay: const TimeOfDay(hour: 7, minute: 0),
      dueDays: {},
      filter: filter,
    );
    expect(goal.filter, filter);
  });
  test('clampAttributeForCadence: weekly cannot use start/end time', () {
    expect(
      GoalEditViewModel.clampAttributeForCadence(
        GoalCadence.weekly,
        GoalSelectedAttribute.endTime,
      ),
      GoalSelectedAttribute.count,
    );
    expect(
      GoalEditViewModel.clampAttributeForCadence(
        GoalCadence.daily,
        GoalSelectedAttribute.endTime,
      ),
      GoalSelectedAttribute.endTime,
    );
  });

  test('showDueDays only for daily goals', () {
    expect(GoalEditViewModel.showDueDays(cadence: GoalCadence.daily), isTrue);
    expect(GoalEditViewModel.showDueDays(cadence: GoalCadence.weekly), isFalse);
  });
}
