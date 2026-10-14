import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_people/data/meeting/meeting_list.dart';
import 'package:nx_people/data/meeting/meeting_visits.dart';
import 'package:nx_people/domain/person/person.dart';
import 'package:nx_people/features/meeting/meetings_page.dart';

void main() {
  test('visit uses local time and event/place relations', () {
    final visit = visitFromModel(
      Model.fromJson({
        'id': 1,
        'start_time': '2026-10-30T20:00:00',
        'Event': [
          {'id': 2, 'name': 'SF Hardware Meetup'},
        ],
        'Place': [
          {'id': 3, 'name': 'Antler'},
        ],
      }),
    );
    expect(visit.name, 'SF Hardware Meetup');
    expect(visit.description, 'Antler');
    expect(visit.displayDate, DateTime(2026, 10, 30, 20));
    expect(visit.startTime!.isUtc, isFalse);
  });

  testWidgets('visit precedes meetings and times appear above their cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    DateTime at(int minute) =>
        DateTime(now.year, now.month, now.day, 20, minute);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          meetingVisitsProvider.overrideWith(
            (_) async => [
              PersonMeeting(
                id: 1,
                name: 'SF Hardware Meetup',
                description: 'Antler',
                startTime: at(0),
              ),
            ],
          ),
          allMeetingsProvider.overrideWith(
            (_) async => [
              PersonMeeting(
                id: 3,
                name: 'Meeting with Viola',
                startTime: at(27),
              ),
              PersonMeeting(
                id: 2,
                name: 'Meeting with Dave',
                startTime: at(15),
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: MeetingsPage())),
      ),
    );
    await tester.pumpAndSettle();
    final event = find.text('SF Hardware Meetup');
    final dave = find.text('Meeting with Dave');
    final viola = find.text('Meeting with Viola');
    expect(tester.getTopLeft(event).dy, lessThan(tester.getTopLeft(dave).dy));
    expect(tester.getTopLeft(dave).dy, lessThan(tester.getTopLeft(viola).dy));
    for (final pair in [
      ('8:00 PM', event),
      ('8:15 PM', dave),
      ('8:27 PM', viola),
    ]) {
      expect(
        tester.getBottomLeft(find.text(pair.$1)).dy,
        lessThan(tester.getTopLeft(pair.$2).dy),
      );
    }
    Material card(Finder f) => tester
        .widgetList<Material>(
          find.ancestor(of: f, matching: find.byType(Material)),
        )
        .first;
    expect(card(event).color, isNot(card(dave).color));
    expect(find.text('Antler'), findsOneWidget);
  });
}
