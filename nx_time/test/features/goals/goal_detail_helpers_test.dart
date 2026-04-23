import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/features/goals/goal_detail/goal_detail_helpers.dart';

void main() {
  group('formatWallClock12h', () {
    test('converts 07:00:00 to 7 AM', () {
      expect(formatWallClock12h('07:00:00'), '7 AM');
    });
    test('converts 12:30:00 to 12:30 PM', () {
      expect(formatWallClock12h('12:30:00'), '12:30 PM');
    });
    test('converts 00:15:00 to 12:15 AM', () {
      expect(formatWallClock12h('00:15:00'), '12:15 AM');
    });
  });
}
