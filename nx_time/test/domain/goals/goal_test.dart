import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/domain/goals/goal.dart';
import 'package:nx_time/domain/goals/goal_cadence.dart';
import 'package:nx_time/domain/goals/goal_selected_attribute.dart';
import 'package:nx_time/domain/goals/goal_threshold.dart';

void main() {
  test('Goal.draft() has expected defaults', () {
    final g = Goal.draft();
    expect(g.cadence, GoalCadence.daily);
    expect(g.active, isTrue);
    expect(g.actionModelTypeName, 'Sleep');
    expect(g.selectedAttribute, GoalSelectedAttribute.duration);
  });

  test('copyWith preserves unspecified fields', () {
    final g = Goal(
      id: 5,
      label: 'A',
      cadence: GoalCadence.weekly,
      actionModelTypeName: 'Gym',
      selectedAttribute: GoalSelectedAttribute.count,
      op: GoalThresholdOp.gte,
      thresholdValue: 3,
    );
    final u = g.copyWith(label: 'B');
    expect(u.id, 5);
    expect(u.label, 'B');
    expect(u.thresholdValue, 3);
  });
}
