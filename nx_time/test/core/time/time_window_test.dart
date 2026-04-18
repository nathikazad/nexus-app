import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/core/time/time_window.dart';

void main() {
  test('overlaps half-open window', () {
    final w = TimeWindow(
      start: DateTime(2026, 4, 18, 0, 0),
      end: DateTime(2026, 4, 19, 0, 0),
    );
    expect(
      w.overlaps(DateTime(2026, 4, 18, 10, 0), DateTime(2026, 4, 18, 11, 0)),
      isTrue,
    );
    expect(
      w.overlaps(DateTime(2026, 4, 17, 23, 0), DateTime(2026, 4, 17, 23, 30)),
      isFalse,
    );
  });
}
