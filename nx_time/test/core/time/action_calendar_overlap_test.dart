import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/core/time/action_calendar_overlap.dart';
import 'package:nx_time/domain/action/action.dart';

void main() {
  test('later calendar day excludes prior-day-only interval (KGQL start_time filter bug)', () {
    final mondayWork = Action(
      id: 1,
      name: 'a',
      modelTypeId: 1,
      startTime: DateTime(2026, 4, 20, 9),
      endTime: DateTime(2026, 4, 20, 17),
    );
    expect(actionOverlapsLocalCalendarDay(mondayWork, DateTime(2026, 4, 21)), isFalse);
  });

  test('same calendar day includes interval', () {
    final a = Action(
      id: 1,
      name: 'a',
      modelTypeId: 1,
      startTime: DateTime(2026, 4, 21, 10),
      endTime: DateTime(2026, 4, 21, 11),
    );
    expect(actionOverlapsLocalCalendarDay(a, DateTime(2026, 4, 21)), isTrue);
  });

  test('overnight block overlaps next calendar day', () {
    final sleep = Action(
      id: 1,
      name: 'a',
      modelTypeId: 1,
      startTime: DateTime(2026, 4, 19, 23),
      endTime: DateTime(2026, 4, 20, 7),
    );
    expect(actionOverlapsLocalCalendarDay(sleep, DateTime(2026, 4, 20)), isTrue);
  });
}
