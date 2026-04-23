import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/domain/action/action.dart';
import 'package:nx_time/domain/action/week_actions.dart';

void main() {
  test('WeekActions holds 7 byDay lists', () {
    final mon = DateTime(2026, 4, 20);
    const all = <Action>[];
    final byDay = List.generate(7, (_) => <Action>[]);
    final wa = WeekActions(weekStart: mon, byDay: byDay, all: all);
    expect(wa.byDay, hasLength(7));
    expect(wa.weekStart, mon);
    expect(wa.all, isEmpty);
  });
}
