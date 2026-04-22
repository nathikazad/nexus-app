import '../goal_parsing.dart';

class GoalStreakWindow {
  const GoalStreakWindow({
    required this.streakCount,
    this.firstPeriod,
    this.lastPeriod,
  });

  final int streakCount;
  final DateTime? firstPeriod;
  final DateTime? lastPeriod;

  factory GoalStreakWindow.fromJson(Map<String, dynamic> json) {
    return GoalStreakWindow(
      streakCount: (json['streak_count'] as num?)?.toInt() ?? 0,
      firstPeriod: parseDateOnly(json['first_period']),
      lastPeriod: parseDateOnly(json['last_period']),
    );
  }

  Map<String, dynamic> toJson() => {
        'streak_count': streakCount,
        'first_period': firstPeriod?.toIso8601String().split('T').first,
        'last_period': lastPeriod?.toIso8601String().split('T').first,
      };
}

/// Matches [get_kgql_streak] / week item `streak` object.
class GoalStreakSummary {
  const GoalStreakSummary({
    required this.isActive,
    required this.currentPeriodHit,
    required this.current,
    required this.max,
  });

  final bool isActive;
  final bool currentPeriodHit;
  final GoalStreakWindow current;
  final GoalStreakWindow max;

  factory GoalStreakSummary.fromJson(Map<String, dynamic> json) {
    return GoalStreakSummary(
      isActive: json['is_active'] as bool? ?? false,
      currentPeriodHit: json['current_period_hit'] as bool? ?? false,
      current: GoalStreakWindow.fromJson(
        (json['current'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      max: GoalStreakWindow.fromJson(
        (json['max'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'is_active': isActive,
        'current_period_hit': currentPeriodHit,
        'current': current.toJson(),
        'max': max.toJson(),
      };
}
