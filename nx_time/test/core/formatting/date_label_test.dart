import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:nx_time/core/formatting/date_label.dart';

void main() {
  setUpAll(() {
    Intl.defaultLocale = 'en_US';
  });

  test('todayTitleLine', () {
    final d = DateTime(2026, 4, 18);
    expect(todayTitleLine(d), 'Today — Sat, Apr 18');
  });
}
