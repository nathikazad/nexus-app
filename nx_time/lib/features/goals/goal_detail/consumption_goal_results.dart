import 'package:nx_time/domain/goals/goal_threshold.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/domain/goals/action_goal.dart';
import 'package:nx_time/domain/goals/goal_day_state.dart';

String goalCountText(num n) =>
    n == n.roundToDouble() ? n.toInt().toString() : n.toString();

/// Uses the server result, which applies related Consumable IDs and tags.
class ConsumptionGoalResults extends StatelessWidget {
  const ConsumptionGoalResults({super.key, required this.item});
  final ActionGoalWeekItem item;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final day in item.dailyState)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('EEE, MMM d').format(day.date),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.slate700,
                  ),
                ),
              ),
              Text(
                day.value == null
                    ? '—'
                    : '${goalCountText(day.value!)} of ${goalCountText(item.target.value)}',
                style: TextStyle(
                  fontSize: 13,
                  color: day.state == GoalDayState.hit
                      ? AppColors.goalOnTrack
                      : day.state == GoalDayState.miss
                      ? AppColors.goalMissed
                      : AppColors.slate500,
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class MonthlyGoalProgress extends StatelessWidget {
  const MonthlyGoalProgress({
    super.key,
    required this.item,
    this.activityColor = AppColors.slate900,
  });
  final Color activityColor;
  final ActionGoalWeekItem item;
  @override
  Widget build(BuildContext context) {
    final summary = item.monthSummary;
    final value = summary?['value'] as num?;
    final state = summary?['state'];
    final met = summary?['met'] as bool?;
    final cap =
        item.target.op == GoalThresholdOp.lte ||
        item.target.op == GoalThresholdOp.lt;
    final label = switch (state) {
      'hit' => 'Met',
      'miss' => cap ? 'Limit exceeded' : 'Target not met',
      'not_due' => 'Not active this month',
      _ =>
        met == true && cap
            ? 'Within limit · month in progress'
            : 'Month in progress',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: activityColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                value == null
                    ? '—'
                    : '${goalCountText(value)} of ${goalCountText(item.target.value)}',
                style: TextStyle(
                  fontSize: 13,
                  color: state == 'miss'
                      ? AppColors.goalMissed
                      : AppColors.slate700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            summary == null ? 'Monthly result unavailable' : label,
            style: const TextStyle(fontSize: 12, color: AppColors.slate500),
          ),
        ],
      ),
    );
  }
}
