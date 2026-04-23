/// Monday–Sunday week boundaries in local time (no [Action] / repository).
/// Used by calendar, goals, and [weekActionsProvider] in `features/calendar/`.

/// Monday 00:00:00 of the week containing [weekAnyDay] (local date).
DateTime mondayOfWeek(DateTime weekAnyDay) {
  final d = DateTime(weekAnyDay.year, weekAnyDay.month, weekAnyDay.day);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}

/// True if local "today" falls in the Mon–Sun week that starts at [monday] (date-normalized).
bool weekContainsToday(DateTime monday) {
  final m0 = DateTime(monday.year, monday.month, monday.day);
  final t = DateTime.now();
  final today0 = DateTime(t.year, t.month, t.day);
  final end = m0.add(const Duration(days: 7));
  return !today0.isBefore(m0) && today0.isBefore(end);
}

/// True if [monday] (date-normalized) is the current calendar week’s Monday.
bool isWeekCurrent(DateTime monday) {
  final t = DateTime.now();
  return mondayOfWeek(t) == DateTime(monday.year, monday.month, monday.day);
}
