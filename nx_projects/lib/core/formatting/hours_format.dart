/// e.g. "4h" / "1.5h"
String formatHours(double h) {
  if (h == h.roundToDouble()) {
    return '${h.toInt()}h';
  }
  return '${h}h';
}

/// e.g. "2h 5m" / "45m" / "2h"
String formatHoursMinutes(double h) {
  final totalMinutes = (h * 60).round();
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours == 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}
