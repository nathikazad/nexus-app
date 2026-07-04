import 'package:flutter_test/flutter_test.dart';
import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/domain/goals/action_goal.dart';
import 'package:nx_time/domain/goals/goal_day_state.dart';
import 'package:nx_time/features/goals/goal_detail/goal_detail_helpers.dart';

void main() {
  group('formatWallClock12h', () {
    test('converts 07:00:00 to 7 AM', () {
      expect(formatWallClock12h('07:00:00'), '7 AM');
    });
    test('converts 12:30:00 to 12:30 PM', () {
      expect(formatWallClock12h('12:30:00'), '12:30 PM');
    });
    test('converts 00:15:00 to 12:15 AM', () {
      expect(formatWallClock12h('00:15:00'), '12:15 AM');
    });
  });

  group('month calendar helpers', () {
    test('buildGoalMonthCalendarCells pads to Monday-Sunday weeks', () {
      final cells = buildGoalMonthCalendarCells(const [], DateTime(2026, 4));
      expect(cells.length, 35);
      expect(cells.first.date, DateTime(2026, 3, 30));
      expect(cells.first.inMonth, isFalse);
      expect(cells[2].date, DateTime(2026, 4));
      expect(cells[2].inMonth, isTrue);
      expect(cells.last.date, DateTime(2026, 5, 3));
      expect(cells.last.inMonth, isFalse);
    });

    test('buildGoalMonthCalendarCells applies states only inside month', () {
      final cells = buildGoalMonthCalendarCells([
        GoalDailyState(date: DateTime(2026, 4, 1), state: GoalDayState.hit),
        GoalDailyState(date: DateTime(2026, 4, 2), state: GoalDayState.miss),
      ], DateTime(2026, 4));
      expect(cells[2].state, GoalDayState.hit);
      expect(cells[3].state, GoalDayState.miss);
      expect(cells.first.state, isNull);
    });

    test('goalMonthConsistencyScore uses elapsed current-month days', () {
      final score = goalMonthConsistencyScore(
        [
          GoalDailyState(date: DateTime(2026, 4, 1), state: GoalDayState.hit),
          GoalDailyState(date: DateTime(2026, 4, 2), state: GoalDayState.miss),
          GoalDailyState(date: DateTime(2026, 4, 3), state: GoalDayState.hit),
          GoalDailyState(date: DateTime(2026, 4, 4), state: GoalDayState.hit),
        ],
        DateTime(2026, 4),
        now: DateTime(2026, 4, 3, 12),
      );
      expect(score.hits, 2);
      expect(score.denominator, 3);
      expect(score.percent, 67);
    });

    test('goalMonthConsistencyScore uses full denominator for past month', () {
      final score = goalMonthConsistencyScore(
        [GoalDailyState(date: DateTime(2026, 4, 1), state: GoalDayState.hit)],
        DateTime(2026, 4),
        now: DateTime(2026, 5, 3),
      );
      expect(score.hits, 1);
      expect(score.denominator, 30);
      expect(score.percent, 3);
    });

    test('goalMonthConsistencyScore has no denominator for future month', () {
      final score = goalMonthConsistencyScore(
        const [],
        DateTime(2026, 6),
        now: DateTime(2026, 5, 3),
      );
      expect(score.hits, 0);
      expect(score.denominator, 0);
      expect(score.percent, isNull);
    });

    test('goalMonthHeatmapColor shades scored days and neutral days', () {
      final date = DateTime(2026, 4);
      expect(
        goalMonthHeatmapColor(
          ActionGoalMonthScoreDay(
            date: date,
            hit: 0,
            total: 2,
            ratio: 0,
            future: false,
          ),
        ),
        AppColors.dotMiss,
      );
      expect(
        goalMonthHeatmapColor(
          ActionGoalMonthScoreDay(
            date: date,
            hit: 2,
            total: 2,
            ratio: 1,
            future: false,
          ),
        ),
        AppColors.dotOk,
      );
      expect(
        goalMonthHeatmapColor(
          ActionGoalMonthScoreDay(
            date: date,
            hit: 0,
            total: 0,
            ratio: null,
            future: false,
          ),
        ),
        AppColors.slate100,
      );
      expect(
        goalMonthHeatmapColor(
          ActionGoalMonthScoreDay(
            date: date,
            hit: 0,
            total: 2,
            ratio: 0,
            future: true,
          ),
        ),
        AppColors.slate100,
      );
    });
  });
}
