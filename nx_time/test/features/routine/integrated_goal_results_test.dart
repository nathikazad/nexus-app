import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/features/goals/goal_detail/goal_evaluation_results.dart';
import 'package:nx_time/dev/fixture_data.dart';

void main() {
  testWidgets(
    'existing detail evidence shows actual start/end and overnight plan',
    (tester) async {
      final goal = previewRoutine().goals.firstWhere((g) => g.label == 'Sleep');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GoalEvaluationResults(item: goal),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mon, Jun 1'));
      await tester.pumpAndSettle();
      expect(find.text('10:00 PM – 6:00 AM · next day'), findsOneWidget);
      expect(find.text('Start · 10:00 PM'), findsOneWidget);
      expect(find.text('End · 6:00 AM'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('gaming evidence separates earliest start and duration', (
    tester,
  ) async {
    final goal = previewRoutine().goals.firstWhere(
      (g) => g.label == 'Gaming limits',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: GoalEvaluationResults(item: goal)),
        ),
      ),
    );
    await tester.tap(find.text('Tue, Jun 2'));
    await tester.pumpAndSettle();
    expect(find.text('Start at or after 21:00'), findsOneWidget);
    expect(find.text('At most 30.0 min'), findsOneWidget);
    expect(find.text('Session 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
