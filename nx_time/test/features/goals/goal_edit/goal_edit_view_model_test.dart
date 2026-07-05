import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/domain/goals/goal_cadence.dart';
import 'package:nx_time/domain/goals/goal_selected_attribute.dart';
import 'package:nx_time/features/goals/goal_edit/goal_edit_view_model.dart';

void main() {
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
    expect(
      GoalEditViewModel.showDueDays(cadence: GoalCadence.daily),
      isTrue,
    );
    expect(
      GoalEditViewModel.showDueDays(cadence: GoalCadence.weekly),
      isFalse,
    );
  });
}
