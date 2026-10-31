import '../goal_parsing.dart';

enum GoalDayState { hit, miss, pending, notDue }

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
    this.value,
    this.startMet,
    this.endMet,
    this.bothMet,
    this.windows = const [],
    this.sessions = const [],
  });

  final num? value;
  final DateTime date;
  final GoalDayState state;
  final bool? startMet, endMet, bothMet;
  final List<Map<String, dynamic>> windows, sessions;

  factory GoalDailyState.fromJson(Map<String, dynamic> json) {
    final d = parseDateOnly(json['date']);
    if (d == null) {
      throw FormatException('GoalDailyState: missing date');
    }
    return GoalDailyState(
      date: d,
      value: json['value'] as num?,
      state: goalDayStateFromString(json['state'] as String?),
      startMet: json['start_met'] as bool?,
      endMet: json['end_met'] as bool?,
      bothMet: json['both_met'] as bool?,
      windows: (json['windows'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      sessions: (json['sessions'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String().split('T').first,
    'state': goalDayStateToString(state),
    if (value != null) 'value': value,
    if (startMet != null) 'start_met': startMet,
    if (endMet != null) 'end_met': endMet,
    if (bothMet != null) 'both_met': bothMet,
    if (windows.isNotEmpty) 'windows': windows,
    if (sessions.isNotEmpty) 'sessions': sessions,
  };
}
