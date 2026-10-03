import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/domain/calendar/calendar_entry.dart';
import 'package:nx_time/domain/calendar/birthday.dart';

void main() {
  test('umbrella groups retain children and tolerate cycles', () {
    final a = CalendarEntry(
      id: 1,
      kind: 'action',
      modelType: 'Work',
      name: 'Project',
      links: [
        {'relation_name': 'action_action', 'id': 2},
      ],
    );
    final b = CalendarEntry(
      id: 2,
      kind: 'action',
      modelType: 'Meet',
      name: 'Discussion',
      links: [
        {'relation_name': 'action_action', 'id': 1},
      ],
    );
    final groups = groupCalendarEntries([a, b]);
    expect(groups.length, 1);
    expect(groups.single.descendants.map((e) => e.id), [2]);
  });

  test('birthday validates real dates and supports an unknown year', () {
    for (final s in ['1990-05-14', '--02-29', '2000-02-29']) {
      expect(validBirthday(s), isTrue, reason: s);
    }
    for (final s in [
      '--02-30',
      '2025-02-29',
      '--13-01',
      'May 14',
      '0000-01-01',
    ]) {
      expect(validBirthday(s), isFalse, reason: s);
    }
  });
  test('half-open intervals span midnight without an extra ending day', () {
    final e = CalendarEntry(
      id: 1,
      kind: 'event',
      modelType: 'Event',
      name: 'Conference',
      start: DateTime(2026, 10, 5, 23),
      end: DateTime(2026, 10, 7),
    );
    expect(e.occursOn(DateTime(2026, 10, 5)), isTrue);
    expect(e.occursOn(DateTime(2026, 10, 6)), isTrue);
    expect(e.occursOn(DateTime(2026, 10, 7)), isFalse);
  });
  test(
    'wire keeps event and attendance clocks, identity and status separate',
    () {
      final feed = CalendarFeed.fromJson({
        'entries': [
          {
            'id': 1,
            'kind': 'event',
            'model_type': 'Event',
            'name': 'Conference',
            'start': '2026-10-05T09:00:00',
            'attributes': {'start_time': '2026-10-05T09:00:00'},
            'attendance': [
              {
                'id': 2,
                'model_type': 'Goto',
                'name': 'Attendance',
                'attributes': {
                  'planning_status': 'skipped',
                  'scheduled_start_time': '2026-10-05T13:00:00',
                },
              },
            ],
          },
        ],
      });
      final event = feed.entries.single;
      expect(event.start, DateTime(2026, 10, 5, 9));
      expect(event.attendance.single.id, 2);
      expect(event.attendance.single.status, 'skipped');
      expect(
        event.attendance.single.time('scheduled_start_time'),
        DateTime(2026, 10, 5, 13),
      );
      expect(event.attendance.single.time('start_time'), isNull);
    },
  );
}
