import '../goal_parsing.dart';

enum GoalDayState {
  hit,
  miss,
  pending,
  notDue,
}

GoalDayState goalDayStateFromString(String? s) {
  switch (s) {
    case 'hit':
      return GoalDayState.hit;
    case 'miss':
      return GoalDayState.miss;
    case 'pending':
      return GoalDayState.pending;
    case 'not_due':
      return GoalDayState.notDue;
    default:
      throw FormatException('Unknown goal day state: $s');
  }
}

String goalDayStateToString(GoalDayState s) {
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
  });

  final DateTime date;
  final GoalDayState state;

  factory GoalDailyState.fromJson(Map<String, dynamic> json) {
    final d = parseDateOnly(json['date']);
    if (d == null) {
      throw FormatException('GoalDailyState: missing date');
    }
    return GoalDailyState(
      date: d,
      state: goalDayStateFromString(json['state'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String().split('T').first,
        'state': goalDayStateToString(state),
      };
}
