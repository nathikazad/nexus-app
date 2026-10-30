import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nx_time/core/theme/app_theme.dart';
import 'package:nx_time/domain/goals/action_goal.dart';
import 'package:nx_time/domain/goals/goal_day_state.dart';
import 'package:nx_time/domain/goals/goal_evaluation.dart';

/// Daily evidence within the existing goal detail, using its typography/palette.
class GoalEvaluationResults extends StatelessWidget {
  const GoalEvaluationResults({super.key, required this.item});
  final ActionGoalWeekItem item;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final day in item.dailyState) _DayResult(item: item, day: day),
    ],
  );
}

String _time(DateTime? d) =>
    d == null ? 'Not logged' : DateFormat('h:mm a').format(d);
String _status(GoalDayState s) => switch (s) {
  GoalDayState.hit => 'Met',
  GoalDayState.miss => 'Not met',
  GoalDayState.pending => 'Pending',
  GoalDayState.notDue => 'Not due',
};
Color _color(GoalDayState s) => switch (s) {
  GoalDayState.hit => AppColors.goalOnTrack,
  GoalDayState.miss => AppColors.goalMissed,
  _ => AppColors.slate400,
};

class _DayResult extends StatelessWidget {
  const _DayResult({required this.item, required this.day});
  final ActionGoalWeekItem item;
  final GoalDailyState day;
  @override
  Widget build(BuildContext context) {
    final scheduled = item.evaluation == GoalEvaluation.schedule;
    final label = scheduled
        ? adherenceLabel(day.state, day.startMet, day.endMet)
        : _status(day.state);
    final rules = item.restrictions ?? {};
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.slate100)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 16),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('EEE, MMM d').format(day.date),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate700,
                  ),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _color(day.state),
                ),
              ),
            ],
          ),
          children: [
            if (scheduled && day.windows.isEmpty)
              Text(
                day.state == GoalDayState.notDue
                    ? 'Not scheduled'
                    : 'Results unavailable',
                style: const TextStyle(fontSize: 12, color: AppColors.slate500),
              ),
            for (final w in day.windows) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_time(w.scheduledStart)} – ${_time(w.scheduledEnd)}${DateUtils.isSameDay(w.scheduledStart, w.scheduledEnd) ? '' : ' · next day'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.slate500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _Check(
                label: 'Start',
                detail: _time(w.actualStart),
                met: w.startMet,
                pending: w.state == GoalDayState.pending,
              ),
              _Check(
                label: 'End',
                detail: _time(w.actualEnd),
                met: w.endMet,
                pending: w.state == GoalDayState.pending,
              ),
              const SizedBox(height: 8),
            ],
            if (!scheduled) ...[
              if (day.sessions.isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    day.state == GoalDayState.hit
                        ? 'No sessions · limits met'
                        : day.state == GoalDayState.notDue
                        ? 'Not due'
                        : 'No sessions yet',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.slate500,
                    ),
                  ),
                ),
              for (var i = 0; i < day.sessions.length; i++) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Session ${i + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate700,
                    ),
                  ),
                ),
                if (rules['not_before'] != null)
                  _Check(
                    label: 'Start at or after ${rules['not_before']}',
                    met: day.sessions[i].notBeforeMet,
                  ),
                if (rules['max_duration_seconds'] != null)
                  _Check(
                    label:
                        'At most ${(rules['max_duration_seconds'] as num) / 60} min',
                    met: day.sessions[i].durationMet,
                  ),
                const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({
    required this.label,
    required this.met,
    this.detail,
    this.pending = false,
  });
  final String label;
  final String? detail;
  final bool? met;
  final bool pending;
  @override
  Widget build(BuildContext context) {
    final state = met == true
        ? GoalDayState.hit
        : met == null || pending
        ? GoalDayState.pending
        : GoalDayState.miss;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            state == GoalDayState.hit
                ? Icons.check
                : state == GoalDayState.pending
                ? Icons.more_horiz
                : Icons.close,
            size: 14,
            color: _color(state),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label${detail == null ? '' : ' · $detail'}',
              style: const TextStyle(fontSize: 12, color: AppColors.slate600),
            ),
          ),
          Text(
            _status(state),
            style: TextStyle(fontSize: 11, color: _color(state)),
          ),
        ],
      ),
    );
  }
}
