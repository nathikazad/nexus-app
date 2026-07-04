@Tags(['widget'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/domain/goals/action_goal.dart';
import 'package:nx_time/domain/goals/goal_cadence.dart';
import 'package:nx_time/domain/goals/goal_day_state.dart';
import 'package:nx_time/domain/goals/goal_streak.dart';
import 'package:nx_time/domain/goals/goal_threshold.dart';
import 'package:nx_time/features/goals/goal_detail/goal_detail_helpers.dart';
import 'package:nx_time/features/goals/goal_detail/goal_detail_page.dart';

import '../_support/fake_action_repository.dart';
import '../_support/fake_goal_repository.dart';
import '../_support/pump_app.dart';

void main() {
  testWidgets('goal detail body renders while month calendar loads', (
    tester,
  ) async {
    final nowMonth = monthStartOf(DateTime.now());
    final repo = _SlowMonthGoalRepository(
      actionWeek: ActionGoalsWeek(
        weekStart: mondayOfWeekStart(DateTime.now()),
        items: [_goalItem(nowMonth)],
      ),
    );

    await pumpAppWith(
      tester,
      child: const GoalDetailPage(goalId: 1),
      overrides: [
        authenticatedUserProvider.overrideWith(
          (ref) async => User(userId: '1', preset: BackendPreset.localhost),
        ),
        actionRepositoryProvider.overrideWith(
          (ref) => FakeActionRepository(initial: const []),
        ),
        goalRepositoryProvider.overrideWithValue(repo),
      ],
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Wake up before 7am'), findsOneWidget);
    expect(find.text('Loading month...'), findsOneWidget);

    repo.completeMonth(
      ActionGoalsMonth(monthStart: nowMonth, items: [_goalItem(nowMonth)]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Loading month...'), findsNothing);
  });

  testWidgets('goal detail next month requests following month', (
    tester,
  ) async {
    final nowMonth = monthStartOf(DateTime.now());
    final fake = FakeGoalRepository(
      actionWeek: ActionGoalsWeek(
        weekStart: mondayOfWeekStart(DateTime.now()),
        items: [_goalItem(nowMonth)],
      ),
      actionMonth: ActionGoalsMonth(
        monthStart: nowMonth,
        items: [_goalItem(nowMonth)],
      ),
    );

    await pumpAppWith(
      tester,
      child: const GoalDetailPage(goalId: 1),
      overrides: [
        authenticatedUserProvider.overrideWith(
          (ref) async => User(userId: '1', preset: BackendPreset.localhost),
        ),
        actionRepositoryProvider.overrideWith(
          (ref) => FakeActionRepository(initial: const []),
        ),
        goalRepositoryProvider.overrideWithValue(fake),
      ],
    );
    await tester.pumpAndSettle();

    expect(fake.requestedMonthStarts, [nowMonth]);

    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();

    expect(fake.requestedMonthStarts.last, addCalendarMonths(nowMonth, 1));
  });
}

class _SlowMonthGoalRepository extends FakeGoalRepository {
  _SlowMonthGoalRepository({required super.actionWeek});

  Completer<ActionGoalsMonth>? _monthCompleter;

  @override
  Future<ActionGoalsMonth> getActionGoalsMonth({
    required DateTime monthStart,
    int? goalId,
  }) {
    requestedMonthStarts.add(monthStart);
    _monthCompleter = Completer<ActionGoalsMonth>();
    return _monthCompleter!.future;
  }

  void completeMonth(ActionGoalsMonth month) {
    _monthCompleter?.complete(month);
  }
}

ActionGoalWeekItem _goalItem(DateTime monthStart) {
  return ActionGoalWeekItem(
    id: 1,
    label: 'Wake up before 7am',
    cadence: GoalCadence.daily,
    modelType: 'Sleep',
    selectedAttribute: 'end_time',
    aggregation: 'count',
    target: const GoalTarget(op: GoalThresholdOp.gte, value: 1),
    dailyState: [GoalDailyState(date: monthStart, state: GoalDayState.hit)],
    streak: const GoalStreakSummary(
      isActive: true,
      currentPeriodHit: true,
      current: GoalStreakWindow(streakCount: 1),
      max: GoalStreakWindow(streakCount: 1),
    ),
  );
}
