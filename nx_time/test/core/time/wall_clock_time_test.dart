import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/core/time/wall_clock_time.dart';

void main() {
  test('asStoredLocalWallClock strips UTC flag', () {
    final utc = DateTime.utc(2024, 6, 15, 14, 30);
    final local = asStoredLocalWallClock(utc);
    expect(local.isUtc, false);
    expect(local.hour, 14);
    expect(local.minute, 30);
  });
}
