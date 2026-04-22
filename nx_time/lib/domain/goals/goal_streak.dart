class GoalStreakWindow {
  const GoalStreakWindow({
    required this.streakCount,
    this.firstPeriod,
    this.lastPeriod,
  });

  final int streakCount;
  final DateTime? firstPeriod;
  final DateTime? lastPeriod;
}

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
}
