import 'package:nx_time/domain/goals/goal_day_state.dart';

enum GoalEvaluation { aggregate, schedule, restrictions }

GoalEvaluation goalEvaluationFromString(String value) => switch (value) {
  'aggregate' => GoalEvaluation.aggregate,
  'schedule' => GoalEvaluation.schedule,
  'restrictions' => GoalEvaluation.restrictions,
  _ => throw FormatException('Unknown goal evaluation: $value'),
};

/// Ignore transport offsets without shifting the entered local calendar/clock.
DateTime? goalWallClock(dynamic value) {
  if (value == null) return null;
  final raw = value.toString().replaceFirst(
    RegExp(r'(Z|[+-]\d{2}:?\d{2})$'),
    '',
  );
  return DateTime.parse(raw);
}

class GoalWindowResult {
  const GoalWindowResult({
    required this.entryIndex,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.actionId,
    this.actualStart,
    this.actualEnd,
    required this.startMet,
    required this.endMet,
    required this.bothMet,
    required this.state,
  });
  final int entryIndex;
  final DateTime scheduledStart, scheduledEnd;
  final int? actionId;
  final DateTime? actualStart, actualEnd;
  final bool startMet, endMet, bothMet;
  final GoalDayState state;
  factory GoalWindowResult.fromJson(Map<String, dynamic> j) => GoalWindowResult(
    entryIndex: (j['entry_index'] as num).toInt(),
    scheduledStart: goalWallClock(j['scheduled_start'])!,
    scheduledEnd: goalWallClock(j['scheduled_end'])!,
    actionId: (j['action_id'] as num?)?.toInt(),
    actualStart: goalWallClock(j['actual_start']),
    actualEnd: goalWallClock(j['actual_end']),
    startMet: j['start_met'] as bool,
    endMet: j['end_met'] as bool,
    bothMet: j['both_met'] as bool,
    state: goalDayStateFromKgql(j['state'] as String),
  );
}

class GoalSessionResult {
  const GoalSessionResult({
    required this.actionId,
    this.durationMet,
    this.notBeforeMet,
    this.met,
  });
  final int actionId;
  final bool? durationMet, notBeforeMet, met;
  factory GoalSessionResult.fromJson(Map<String, dynamic> j) =>
      GoalSessionResult(
        actionId: (j['action_id'] as num).toInt(),
        durationMet: j['duration_met'] as bool?,
        notBeforeMet: j['not_before_met'] as bool?,
        met: j['met'] as bool?,
      );
}

String adherenceLabel(GoalDayState state, bool? start, bool? end) {
  if (state == GoalDayState.notDue) return 'Not scheduled';
  if (state == GoalDayState.pending) return 'Pending';
  if (start == true && end == true) return 'Both met';
  if (start == true) return 'Start only';
  if (end == true) return 'End only';
  return 'Neither met';
}
