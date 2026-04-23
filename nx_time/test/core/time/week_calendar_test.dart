import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/core/time/week_calendar.dart';

void main() {
  test('mondayOfWeek returns Monday 00:00 for any day in that week', () {
    final wed = DateTime(2026, 4, 22);
    final mon = mondayOfWeek(wed);
    expect(mon.weekday, DateTime.monday);
    expect(mon.day, 20);
    expect(mon.hour, 0);
  });
}
