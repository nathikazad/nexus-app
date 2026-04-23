import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/domain/goals/goal_selected_attribute.dart';

void main() {
  test('goalSelectedAttributeByName round-trip', () {
    for (final a in GoalSelectedAttribute.values) {
      final s = goalSelectedAttributeName(a);
      expect(goalSelectedAttributeByName(s), a);
    }
    expect(goalSelectedAttributeByName('nope'), isNull);
  });
}
