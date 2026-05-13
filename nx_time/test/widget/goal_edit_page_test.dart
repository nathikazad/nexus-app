@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/features/goals/goal_edit/goal_edit_page.dart';
import 'package:nx_time/features/goals/goal_edit/goal_edit_providers.dart';

import '../_support/fake_goal_repository.dart';
import '../_support/pump_app.dart';

void main() {
  testWidgets('create: enter name and save calls repository', (tester) async {
    final fake = FakeGoalRepository();
    await pumpAppWith(
      tester,
      child: const GoalEditPage(),
      overrides: [
        goalRepositoryProvider.overrideWithValue(fake),
        goalActionTypeOptionsProvider.overrideWith(
          (ref) async => const [GoalActionTypeOption(id: 1, name: 'Sleep')],
        ),
      ],
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'My sleep goal');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(fake.lastCreated, isNotNull);
    expect(fake.lastCreated!.label, 'My sleep goal');
  });
}
