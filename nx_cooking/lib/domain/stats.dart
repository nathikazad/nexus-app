final class StatMealRow {
  const StatMealRow({
    required this.title,
    required this.whenLabel,
    required this.durationLabel,
  });

  final String title;
  final String whenLabel;
  final String durationLabel;
}

final class CookingStatsSnapshot {
  const CookingStatsSnapshot({
    required this.mealsCooked,
    required this.totalTimeLabel,
    required this.cookedThisWeek,
  });

  final String mealsCooked;
  final String totalTimeLabel;
  final List<StatMealRow> cookedThisWeek;
}
