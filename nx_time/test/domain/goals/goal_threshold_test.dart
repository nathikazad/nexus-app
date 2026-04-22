import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/domain/goals/goal_threshold.dart';

void main() {
  test('round-trip all ops', () {
    for (final op in GoalThresholdOp.values) {
      expect(goalThresholdOpFromKgql(goalThresholdOpToKgql(op)), op);
    }
  });

  test('unknown throws', () {
    expect(() => goalThresholdOpFromKgql('!='), throwsFormatException);
  });
}
