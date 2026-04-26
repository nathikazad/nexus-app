import 'package:intl/intl.dart';

/// Monday 00:00:00 (local) for the week that contains [day].
DateTime weekStartMonday(DateTime day) {
  final d = DateTime(day.year, day.month, day.day);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// e.g. `Oct 16 – 22` or `Dec 30 – Jan 5` across month boundaries.
String formatWeekRangeLabel(DateTime weekStartMondayLocal) {
  final start = dateOnly(weekStartMondayLocal);
  final end = start.add(const Duration(days: 6));
  final monthDay = DateFormat('MMM d');
  if (start.month == end.month && start.year == end.year) {
    return '${monthDay.format(start)} – ${end.day}';
  }
  return '${monthDay.format(start)} – ${monthDay.format(end)}';
}
