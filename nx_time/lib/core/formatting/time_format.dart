import 'package:intl/intl.dart';

/// Duration as "7h 45m" or "45m" (matches Today row / detail center).
String formatDurationHm(DateTime? start, DateTime? end) {
  if (start == null || end == null) return '—';
  final d = end.difference(start);
  if (d.inMinutes <= 0) return '—';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}

/// Time range using locale time format (e.g. "9:30 AM – 10:15 AM").
String formatTimeRange(DateFormat timeFmt, DateTime? start, DateTime? end) {
  if (start == null && end == null) return '—';
  if (start != null && end != null) {
    return '${timeFmt.format(start)} – ${timeFmt.format(end)}';
  }
  if (start != null) return timeFmt.format(start);
  return timeFmt.format(end!);
}

/// "Wed, Jun 15, 2:30 PM" style (picker / form fields).
String formatActionDateTimeLine(DateTime dt) {
  return DateFormat('EEE, MMM d').add_jm().format(dt);
}
