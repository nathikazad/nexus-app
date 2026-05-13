/// Stored / API cadence for a [Goal] row.
enum GoalCadence { daily, weekly, monthly }

/// Parses API string values (`daily` \| `weekly` \| `monthly`).
GoalCadence goalCadenceFromKgql(String? raw) {
  switch (raw) {
    case 'daily':
      return GoalCadence.daily;
    case 'weekly':
      return GoalCadence.weekly;
    case 'monthly':
      return GoalCadence.monthly;
    default:
      throw FormatException('Unknown goal cadence: $raw');
  }
}

String goalCadenceToKgql(GoalCadence c) {
  switch (c) {
    case GoalCadence.daily:
      return 'daily';
    case GoalCadence.weekly:
      return 'weekly';
    case GoalCadence.monthly:
      return 'monthly';
  }
}
