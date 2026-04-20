import 'package:nx_time/domain/action/action.dart';

/// True if [action]'s interval overlaps the half-open local calendar window
/// `[dayStart, dayEnd)` (typically one local day).
bool actionOverlapsHalfOpen(Action m, DateTime dayStart, DateTime dayEnd) {
  final start = m.startTime;
  final end = m.endTime;
  if (start == null && end == null) return false;
  final s = start ?? end!;
  final e = end ?? start!.add(const Duration(hours: 1));
  return s.isBefore(dayEnd) && e.isAfter(dayStart);
}

/// True if [action] overlaps [dayLocal]'s calendar day in local time.
bool actionOverlapsLocalCalendarDay(Action m, DateTime dayLocal) {
  final dayStart = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  return actionOverlapsHalfOpen(m, dayStart, dayEnd);
}
