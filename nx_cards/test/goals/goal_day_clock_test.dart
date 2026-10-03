import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/goals/goal_day_clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('checks stale checkpoint at launch, midnight and resume only', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      GoalDayClock.preferenceKey: '2026-9-30',
    });
    final prefs = await SharedPreferences.getInstance();
    var now = DateTime(2026, 10, 3, 23, 59, 30);
    final emitted = <DateTime>[];
    final clock = GoalDayClock(prefs, now: () => now);
    clock.changes.listen(emitted.add);
    await tester.pump();
    expect(emitted, [now]);
    expect(prefs.getString(GoalDayClock.preferenceKey), '2026-10-3');
    await tester.pump(const Duration(seconds: 29));
    expect(emitted, hasLength(1));
    now = DateTime(2026, 10, 4);
    await tester.pump(const Duration(seconds: 1));
    expect(emitted, hasLength(2));
    expect(prefs.getString(GoalDayClock.preferenceKey), '2026-10-4');
    clock.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(emitted, hasLength(2));
    now = DateTime(2026, 10, 6, 9);
    clock.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(emitted, hasLength(3));
    expect(prefs.getString(GoalDayClock.preferenceKey), '2026-10-6');
    clock.dispose();
    await tester.pump();
  });
}
