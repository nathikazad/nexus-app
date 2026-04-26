import 'package:nx_cooking/domain/meal_status.dart';

/// One day block in the Week tab.
final class WeekDaySection {
  const WeekDaySection({
    required this.date,
    required this.dayLabel,
    required this.isToday,
    required this.meal,
  });

  /// Local calendar day (this section).
  final DateTime date;

  final String dayLabel;
  final bool isToday;

  /// Null if no meal row for that day.
  final WeekMealCard? meal;
}

final class WeekMealCard {
  const WeekMealCard({
    required this.recipeId,
    required this.title,
    required this.kind,
    required this.badge,
    required this.subtitle,
    this.showPing = false,
  });

  /// Recipe to open when the card is tapped.
  final int recipeId;
  final String title;
  final MealCardKind kind;

  /// e.g. "3/4 steps", "0/6 items", or empty when not shown.
  final String badge;
  final String subtitle;
  final bool showPing;
}
