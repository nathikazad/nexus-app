import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/domain/schedules/schedule_plan.dart';
import 'package:nx_time/features/today/widgets/upcoming_schedule.dart';

void main() {
  test(
    'remaining windows respect local time, weekdays, expiration and overnight sleep',
    () {
      SchedulePlan plan(
        int id,
        String name,
        String start,
        String end, {
        String day = 'friday',
        int offset = 0,
        DateTime? until,
      }) => SchedulePlan(
        id: id,
        name: name,
        endDate: until,
        entries: [
          {
            'days': [day],
            'start_time': start,
            'end_time': end,
            'end_day_offset': offset,
          },
        ],
      );
      final plans = [
        plan(1, 'Sleep', '21:30', '05:30', offset: 1),
        plan(2, 'Morning workout', '11:00', '11:20'),
        plan(3, 'Evening workout', '19:00', '19:20'),
        plan(4, 'Games', '21:00', '21:30'),
        plan(5, 'Old yoga', '20:00', '20:30', until: DateTime(2026, 7, 31)),
        plan(6, 'Saturday yoga', '20:00', '20:30', day: 'saturday'),
      ];
      final windows = upcomingScheduleWindows(
        plans,
        DateTime(2026, 10, 30, 18),
      );
      expect(windows.map((w) => w.plan.name), [
        'Evening workout',
        'Games',
        'Sleep',
      ]);
      expect(windows.last.end, DateTime(2026, 10, 31, 5, 30));
      expect(
        upcomingScheduleWindows(
          plans,
          DateTime(2026, 10, 30, 19),
        ).first.plan.name,
        'Evening workout',
      );
      expect(
        upcomingScheduleWindows(plans, DateTime(2026, 10, 30, 22)),
        isEmpty,
      );
    },
  );
}
