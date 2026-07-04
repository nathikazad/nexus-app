import '../goal_parsing.dart';

class ActionGoalMonthScoreDay {
  const ActionGoalMonthScoreDay({
    required this.date,
    required this.hit,
    required this.total,
    required this.ratio,
    required this.future,
  });

  final DateTime date;
  final int hit;
  final int total;
  final num? ratio;
  final bool future;

  factory ActionGoalMonthScoreDay.fromJson(Map<String, dynamic> json) {
    final d = parseDateOnly(json['date']);
    if (d == null) {
      throw FormatException('ActionGoalMonthScoreDay: missing date');
    }
    return ActionGoalMonthScoreDay(
      date: d,
      hit: (json['hit'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      ratio: json['ratio'] as num?,
      future: json['future'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String().split('T').first,
        'hit': hit,
        'total': total,
        'ratio': ratio,
        'future': future,
      };
}

class ActionGoalMonthScoreResponse {
  const ActionGoalMonthScoreResponse({
    required this.monthStart,
    required this.days,
  });

  final DateTime monthStart;
  final List<ActionGoalMonthScoreDay> days;

  factory ActionGoalMonthScoreResponse.fromJson(Map<String, dynamic> json) {
    final ms = parseDateOnly(json['month_start']);
    if (ms == null) {
      throw FormatException(
        'ActionGoalMonthScoreResponse: missing month_start',
      );
    }
    final daysJson = json['days'] as List<dynamic>?;
    final days = (daysJson ?? const [])
        .map((e) {
          if (e is Map<String, dynamic>) {
            return ActionGoalMonthScoreDay.fromJson(e);
          }
          if (e is Map) {
            return ActionGoalMonthScoreDay.fromJson(
              Map<String, dynamic>.from(e),
            );
          }
          return null;
        })
        .whereType<ActionGoalMonthScoreDay>()
        .toList();
    return ActionGoalMonthScoreResponse(monthStart: ms, days: days);
  }

  factory ActionGoalMonthScoreResponse.emptyForMonth(DateTime monthStart) {
    return ActionGoalMonthScoreResponse(monthStart: monthStart, days: const []);
  }

  Map<String, dynamic> toJson() => {
        'month_start': monthStart.toIso8601String().split('T').first,
        'days': days.map((e) => e.toJson()).toList(),
      };
}
