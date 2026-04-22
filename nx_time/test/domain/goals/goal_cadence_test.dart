import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/domain/goals/goal_cadence.dart';

void main() {
  test('round-trip all cadences', () {
    for (final c in GoalCadence.values) {
      expect(goalCadenceFromKgql(goalCadenceToKgql(c)), c);
    }
  });

  test('unknown throws', () {
    expect(() => goalCadenceFromKgql('yearly'), throwsFormatException);
  });
}
