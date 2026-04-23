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

  test('showPreferredSlots only for weekly+count', () {
    expect(
      GoalEditViewModel.showPreferredSlots(
        cadence: GoalCadence.weekly,
        attr: GoalSelectedAttribute.count,
      ),
      isTrue,
    );
    expect(
      GoalEditViewModel.showPreferredSlots(
        cadence: GoalCadence.daily,
        attr: GoalSelectedAttribute.count,
      ),
      isFalse,
    );
  });
}
