import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/data/goals/goal_attr_keys.dart';

void main() {
  test('Goal attribute key snapshot', () {
    expect(kGoalModelTypeName, 'Goal');
    expect(kGoalAttrLabel, 'label');
    expect(kGoalAttrMeta, 'meta');
    expect(kGoalAttrThresholdValue, 'threshold_value');
  });
}
