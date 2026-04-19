@Tags(['widget'])
library;

import 'package:flutter/material.dart' hide Action;
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/domain/action/action.dart';
import 'package:nx_time/features/action_detail/action_detail_page.dart';
import 'package:nx_time/features/action_detail/action_detail_view_model.dart';
import 'package:nx_time/features/today/action_fold.dart';

void main() {
  testWidgets('umbrella layout shows Child actions section and child rows', (tester) async {
    final day = DateTime(2026, 4, 18);
    final u = Action(
      id: 1,
      name: 'Trip',
      modelTypeId: 2,
      modelTypeName: 'Goto',
      startTime: DateTime(day.year, day.month, day.day, 8, 0),
      endTime: DateTime(day.year, day.month, day.day, 18, 0),
    );
    final c = Action(
      id: 2,
      name: 'Stop',
      modelTypeId: 3,
      modelTypeName: 'Meet',
      startTime: DateTime(day.year, day.month, day.day, 10, 0),
      endTime: DateTime(day.year, day.month, day.day, 11, 0),
    );
    final row = UmbrellaRow(umbrella: u, children: [c]);
    final args = activityDetailArgsForUmbrella(row, 'Today — Sat, Apr 18');

    await tester.pumpWidget(
      MaterialApp(
        home: ActivityDetailPage(args: args),
      ),
    );

    expect(find.text('Child actions'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);
    expect(find.text('Add another action'), findsOneWidget);
  });
}
