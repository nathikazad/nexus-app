import 'package:nx_time/domain/goals/goal_evaluation.dart';

enum GoalDayState { hit, miss, pending, notDue }

GoalDayState goalDayStateFromKgql(String? raw) {
  switch (raw) {
    case 'hit':
      return GoalDayState.hit;
    case 'miss':
      return GoalDayState.miss;
    case 'pending':
      return GoalDayState.pending;
    case 'not_due':
      return GoalDayState.notDue;
    default:
      throw FormatException('Unknown goal day state: $raw');
  }
}

String goalDayStateToKgql(GoalDayState s) {
  switch (s) {
    case GoalDayState.hit:
      return 'hit';
    case GoalDayState.miss:
      return 'miss';
    case GoalDayState.pending:
      return 'pending';
    case GoalDayState.notDue:
      return 'not_due';
  }
}

class GoalDailyState {
  const GoalDailyState({
    required this.date,
    required this.state,
    this.startMet,
    this.endMet,
    this.bothMet,
    this.windows = const [],
    this.sessions = const [],
  });

  final DateTime date;
  final GoalDayState state;
  final bool? startMet, endMet, bothMet;
  final List<GoalWindowResult> windows;
  final List<GoalSessionResult> sessions;
}
