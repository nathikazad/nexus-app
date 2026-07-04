@Tags(['widget'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_time/data/providers.dart';
import 'package:nx_time/domain/goals/action_goal.dart';
import 'package:nx_time/domain/goals/goal_cadence.dart';
import 'package:nx_time/domain/goals/goal_day_state.dart';
import 'package:nx_time/domain/goals/goal_streak.dart';
import 'package:nx_time/domain/goals/goal_threshold.dart';
import 'package:nx_time/features/goals/goal_detail/goal_detail_helpers.dart';
import 'package:nx_time/features/goals/goals_page.dart';

import '../_support/fake_action_repository.dart';
import '../_support/fake_goal_repository.dart';
import '../_support/pump_app.dart';

void main() {
  testWidgets('goals list renders while month heatmap loads', (tester) async {
    final month = monthStartOf(DateTime.now());
    final repo = _SlowScoreGoalRepository(
      actionWeek: ActionGoalsWeek(
        weekStart: mondayOfWeekStart(DateTime.now()),
        items: [_goalItem(month)],
      ),
    );

    await pumpAppWith(
      tester,
      child: const GoalsPage(),
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
    expect(find.text('Add a goal'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repo.completeScore(
      ActionGoalsMonthScore(
        monthStart: month,
        consistency: const ActionGoalMonthConsistency(
          hit: 1,
          total: 2,
          ratio: 0.5,
        ),
        days: [
          ActionGoalMonthScoreDay(
            date: month,
            hit: 1,
            total: 2,
            ratio: 0.5,
            future: false,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Consistency'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
  });
}

class _SlowScoreGoalRepository extends FakeGoalRepository {
  _SlowScoreGoalRepository({required super.actionWeek});

  Completer<ActionGoalsMonthScore>? _scoreCompleter;

  @override
  Future<ActionGoalsMonthScore> getActionGoalsMonthScore({
    required DateTime monthStart,
    int? goalId,
  }) {
    _scoreCompleter = Completer<ActionGoalsMonthScore>();
    return _scoreCompleter!.future;
  }

  void completeScore(ActionGoalsMonthScore score) {
    _scoreCompleter?.complete(score);
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
