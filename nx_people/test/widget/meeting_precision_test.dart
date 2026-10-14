import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_people/data/person/person_mapper.dart';
import 'package:nx_people/domain/person/person.dart';
import 'package:nx_people/features/meeting/meeting_card.dart';
import 'package:nx_people/features/meeting/meetings_page.dart';

void main() {
  PersonMeeting mapped(Map<String, dynamic> attributes) => personFromModel(
    Model(
      id: 1,
      name: 'Dave',
      modelTypeId: 1,
      relations: {
        'Meet': [
          Model(id: 2, name: 'Meeting', modelTypeId: 2, attributes: attributes),
        ],
      },
    ),
  ).actualMeetings.single;

  test('maps precision and uses only the canonical start time', () {
    final meeting = mapped({
      'start_time': '2026-10-09T00:00:00Z',
      'start_precision': 'date',
      'actual_start_time': '2026-10-13T18:00:00Z',
    });
    expect(meeting.isDateOnly, isTrue);
    expect(meeting.displayDate, DateTime(2026, 10, 9));
    expect(meetingsOnDay([meeting], DateTime(2026, 10, 9)), [meeting]);
    expect(meetingsOnDay([meeting], DateTime(2026, 10, 8)), isEmpty);
    expect(
      mapped({'actual_start_time': '2026-10-13T18:00:00Z'}).startTime,
      isNull,
    );
  });

  test('missing precision keeps datetime behavior', () {
    final meeting = mapped({'start_time': '2026-10-09T18:30:00Z'});
    expect(meeting.startPrecision, 'datetime');
    expect(meeting.isDateOnly, isFalse);
    expect(meeting.displayDate, DateTime.utc(2026, 10, 9, 18, 30).toLocal());
  });

  for (final precision in ['date', 'datetime']) {
    testWidgets(
      '$precision is formatted consistently on cards and detail labels',
      (tester) async {
        final meeting = PersonMeeting(
          id: 2,
          name: 'Meeting',
          startTime: DateTime(2026, 10, 9),
          startPrecision: precision,
        );
        late String label;
        late String date;
        late String clock;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final locale = MaterialLocalizations.of(context);
                date = locale.formatMediumDate(meeting.displayDate!);
                clock = locale.formatTimeOfDay(
                  const TimeOfDay(hour: 0, minute: 0),
                );
                label = meetingDateLabel(context, meeting);
                return Scaffold(body: MeetingCard(meeting: meeting));
              },
            ),
          ),
        );
        if (precision == 'date') {
          expect(label, date);
          expect(find.text(date), findsOneWidget);
          expect(find.text(clock), findsNothing);
        } else {
          expect(label, '$date · $clock');
          expect(find.text(clock), findsOneWidget);
        }
      },
    );
  }
}
