import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:nx_time/features/today/today_view_model.dart';

import '../../_support/test_actions.dart';

void main() {
  setUpAll(() {
    Intl.defaultLocale = 'en_US';
  });

  test('buildTodaySnapshot maps actions to rows and title', () {
    final day = DateTime(2026, 4, 18);
    final actions = [
      sampleAction(
        id: 1,
        name: 'Meet',
        start: DateTime(day.year, day.month, day.day, 9, 0),
        end: DateTime(day.year, day.month, day.day, 10, 0),
      ),
    ];
    final snap = buildTodaySnapshot(actions, day);
    expect(snap.titleLine, 'Today — Sat, Apr 18');
    expect(snap.actions.length, 1);
    expect(snap.sourceActions.length, 1);
    expect(snap.activityBlockCount, 1);
  });
}
