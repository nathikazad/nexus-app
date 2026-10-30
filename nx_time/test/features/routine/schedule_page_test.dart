import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/dev/fixture_data.dart';
import 'package:nx_time/features/schedule/schedule_page.dart';

void main() {
  testWidgets(
    'daily schedule includes independent plans and overnight windows',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            schedulePlansProvider.overrideWith(
              (ref) async => previewRoutine().plans,
            ),
            scheduleInitialDateProvider.overrideWithValue(
              DateTime(2026, 6, 10),
            ),
          ],
          child: const MaterialApp(home: SchedulePage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Video games plan'), findsOneWidget);
      expect(find.text('10:00 PM – 6:00 AM · next day'), findsOneWidget);
      await tester.tap(find.byTooltip('Next day'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing scheduled for this day.'), findsOneWidget);
      await tester.tap(find.byTooltip('Previous day'));
      await tester.pumpAndSettle();
      expect(find.text('Meditation schedule'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
