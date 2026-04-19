@Tags(['widget'])
library;

import 'package:flutter/material.dart' hide Action;
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/domain/action/action.dart';
import 'package:nx_time/features/today/today_view_model.dart';
import 'package:nx_time/features/today/widgets/activity_row.dart';

void main() {
  testWidgets('chevron toggles child list; body onTap is separate', (tester) async {
    final day = DateTime(2026, 4, 18);
    final umbrellaAction = Action(
      id: 1,
      name: 'Root',
      modelTypeId: 1,
      modelTypeName: 'Goto',
      startTime: DateTime(day.year, day.month, day.day, 8, 0),
      endTime: DateTime(day.year, day.month, day.day, 18, 0),
    );
    final child = TodayActivity(
      title: 'Child tile',
      timeRangeLabel: '9:00 AM – 10:00 AM',
      durationLabel: '1h',
      barColor: const Color(0xFF336699),
    );
    final umbrella = TodayUmbrellaActivity(
      title: 'Root',
      timeRangeLabel: '8:00 AM – 6:00 PM',
      durationLabel: '10h',
      barColor: const Color(0xFF112233),
      children: [child],
      umbrellaAction: umbrellaAction,
    );

    var bodyTaps = 0;
    var childTaps = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActivityRow(
            activity: umbrella,
            onTap: () => bodyTaps++,
            onChildTap: (i) => childTaps.add(i),
          ),
        ),
      ),
    );

    expect(find.text('Child tile'), findsNothing);

    await tester.tap(find.byTooltip('Expand'));
    await tester.pumpAndSettle();

    expect(find.text('Child tile'), findsOneWidget);

    await tester.tap(find.text('Root').first);
    expect(bodyTaps, 1);

    await tester.tap(find.text('Child tile'));
    await tester.pump();
    expect(childTaps, [0]);
  });
}
