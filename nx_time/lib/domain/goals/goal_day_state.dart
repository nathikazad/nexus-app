enum GoalDayState {
  hit,
  miss,
  pending,
}

GoalDayState goalDayStateFromKgql(String? raw) {
  switch (raw) {
    case 'hit':
      return GoalDayState.hit;
    case 'miss':
      return GoalDayState.miss;
    case 'pending':
      return GoalDayState.pending;
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
  }
}

class GoalDailyState {
  const GoalDailyState({
    required this.date,
    required this.state,
  });

  final DateTime date;
  final GoalDayState state;
}
