/// Half-open local interval [start, end) for calendar-day logic.
class TimeWindow {
  const TimeWindow({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  bool overlaps(DateTime a, DateTime b) {
    final s = a.isBefore(b) ? a : b;
    final e = a.isBefore(b) ? b : a;
    return s.isBefore(end) && e.isAfter(start);
  }
}
