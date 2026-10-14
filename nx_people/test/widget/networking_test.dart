import 'package:nx_people/data/meeting/meeting_visits.dart';
import 'package:nx_people/data/meeting/meeting_list.dart';
import 'package:nx_people/data/meeting/meeting_time.dart';
import 'package:nx_db/kgql.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_people/features/meeting/meetings_page.dart';
import 'package:nx_people/features/events/events_page.dart';
import 'package:nx_people/data/meeting/networking_events.dart';
import 'package:nx_people/domain/person/person.dart';

void main() {
  test(
    'daily meetings chronological, created date fallback, excludes other days',
    () {
      final day = DateTime(2026, 10, 8);
      final rows = [
        PersonMeeting(
          id: 1,
          name: 'Morning',
          startTime: DateTime(2026, 10, 8, 9),
        ),
        PersonMeeting(
          id: 2,
          name: 'Yesterday',
          startTime: DateTime(2026, 10, 7, 23),
        ),
        PersonMeeting(
          id: 3,
          name: 'Afternoon',
          createdAt: DateTime(2026, 10, 8, 15),
        ),
        const PersonMeeting(id: 4, name: 'Undated'),
      ];
      expect(meetingsOnDay(rows, day).map((m) => m.id), [1, 3]);
    },
  );

  test(
    'event mapping preserves wall-clock dates and accepts only web links',
    () {
      final event = NetworkingEvent.fromModel(
        Model.fromJson({
          'id': 1,
          'name': 'Farmers market',
          'start_time': '2026-10-07T12:30:00',
          'url': 'https://partiful.com/e/example',
          'Place': [
            {'id': 2, 'name': 'Town square'},
          ],
        }),
      );
      expect(event.startTime, DateTime(2026, 10, 7, 12, 30));
      expect(event.location, 'Town square');
      expect(event.url?.host, 'partiful.com');
      expect(
        NetworkingEvent.fromModel(
          Model.fromJson({
            'id': 1,
            'name': 'Unsafe',
            'url': 'javascript:alert(1)',
          }),
        ).url,
        isNull,
      );
    },
  );
  test('events filter the selected day and exclude undated entries', () {
    final events = eventsOnDay([
      NetworkingEvent('Yesterday', '', DateTime(2026, 10, 7)),
      NetworkingEvent('Tomorrow', '', DateTime(2026, 10, 9)),
      const NetworkingEvent('Undated', '', null),
      NetworkingEvent('Today', '', DateTime(2026, 10, 8, 8)),
    ], DateTime(2026, 10, 8, 14));
    expect(events.map((e) => e.name), ['Today']);
    expect(weekRange(DateTime(2026, 12, 28)), 'Dec 28, 2026 – Jan 3, 2027');
  });
  testWidgets('seven visible days and previous next today navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          meetingVisitsProvider.overrideWith((_) async => []),
          allMeetingsProvider.overrideWith(
            (_) async => [
              PersonMeeting(id: 1, name: 'This week', startTime: today),
              PersonMeeting(
                id: 2,
                name: 'Next week meeting',
                startTime: DateTime(today.year, today.month, today.day + 7, 12),
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: MeetingsPage())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('SUN').hitTestable(), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
    await tester.tap(find.byTooltip('Next week'));
    await tester.pumpAndSettle();
    expect(find.text('Next week meeting'), findsOneWidget);
    expect(find.text('This week'), findsNothing);
    await tester.tap(find.byTooltip('Previous week'));
    await tester.pumpAndSettle();
    expect(find.text('This week'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous week'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(find.text('This week'), findsOneWidget);
  });

  testWidgets('events select a day and navigate weeks without mode tabs', (
    tester,
  ) async {
    final week = mondayOf(DateTime.now());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkingEventsProvider.overrideWith(
            (_) async => [
              NetworkingEvent('Monday market', '', week),
              NetworkingEvent(
                'Sunday fair',
                '',
                DateTime(week.year, week.month, week.day + 6, 23, 59),
              ),
              NetworkingEvent(
                'Next Monday',
                '',
                DateTime(week.year, week.month, week.day + 7),
              ),
              const NetworkingEvent('Undated gathering', '', null),
            ],
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: EventsPage())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('All events'), findsNothing);
    expect(find.text('This week'), findsNothing);
    await tester.tap(find.text('SUN'));
    await tester.pumpAndSettle();
    expect(find.text('Sunday fair'), findsOneWidget);
    expect(find.text('Monday market'), findsNothing);
    await tester.tap(find.text('MON'));
    await tester.pumpAndSettle();
    expect(find.text('Monday market'), findsOneWidget);
    expect(find.text('Sunday fair'), findsNothing);
    expect(find.text('Next Monday'), findsNothing);
    await tester.tap(find.byTooltip('Next week'));
    await tester.pumpAndSettle();
    expect(find.text('Next Monday'), findsOneWidget);
    expect(find.text('Sunday fair'), findsNothing);

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(find.text('Next Monday'), findsNothing);
    expect(find.text('Undated gathering'), findsNothing);
  });

  testWidgets('events lists actual event data', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkingEventsProvider.overrideWith(
            (ref) async => [
              NetworkingEvent(
                'Networking night',
                '600 California',
                DateTime.now(),
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: EventsPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Networking night'), findsOneWidget);
    expect(find.textContaining('600 California'), findsOneWidget);
  });
}
