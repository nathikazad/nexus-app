import 'package:flutter/material.dart';
import 'package:nx_time/domain/goals/goal_threshold.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/domain/goals/goal_cadence.dart';
import 'package:nx_time/domain/goals/goal_selected_attribute.dart';
import 'package:nx_time/features/goals/goal_edit/goal_edit_view_model.dart';

void main() {
  test('schedule validation handles overnight windows and calendar dates', () {
    final entries = <Map<String, dynamic>>[
      {
        'days': ['monday'],
        'start_time': '23:00',
        'end_time': '07:00',
      },
    ];
    expect(GoalEditViewModel.scheduleError(entries, null, null), isNotNull);
    entries.single['end_day_offset'] = 1;
    expect(
      GoalEditViewModel.scheduleError(entries, '2026-07-01', '2026-07-31'),
      isNull,
    );
    expect(
      GoalEditViewModel.scheduleError(entries, '2026-02-30', null),
      isNotNull,
    );
    expect(
      GoalEditViewModel.scheduleError(entries, '2026-08-01', '2026-07-31'),
      isNotNull,
    );
    entries.single['days'] = [];
    expect(GoalEditViewModel.scheduleError(entries, null, null), isNotNull);
  });

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
