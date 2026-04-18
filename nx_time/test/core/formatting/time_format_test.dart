import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:nx_time/core/formatting/time_format.dart';

void main() {
  setUpAll(() {
    Intl.defaultLocale = 'en_US';
  });

  group('formatDurationHm', () {
    test('hours and minutes', () {
      final s = DateTime(2026, 4, 18, 9, 0);
      final e = DateTime(2026, 4, 18, 16, 45);
      expect(formatDurationHm(s, e), '7h 45m');
    });

    test('minutes only', () {
      final s = DateTime(2026, 4, 18, 10, 0);
      final e = DateTime(2026, 4, 18, 10, 32);
      expect(formatDurationHm(s, e), '32m');
    });

    test('null inputs', () {
      expect(formatDurationHm(null, DateTime.now()), '—');
    });
  });

  group('formatTimeRange', () {
    test('both times', () {
      final fmt = DateFormat.jm();
      final s = DateTime(2026, 4, 18, 9, 30);
      final e = DateTime(2026, 4, 18, 10, 15);
      expect(formatTimeRange(fmt, s, e), contains('9:30'));
      expect(formatTimeRange(fmt, s, e), contains('10:15'));
    });
  });

  test('formatActionDateTimeLine', () {
    final dt = DateTime(2026, 4, 18, 14, 5);
    final s = formatActionDateTimeLine(dt);
    expect(s, contains('Sat, Apr 18'));
    expect(s, contains('2:05'));
    expect(s, contains('PM'));
  });
}
