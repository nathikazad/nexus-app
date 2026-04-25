import 'package:intl/intl.dart';

/// "Today" / "Yesterday" / "Apr 25" for [date] in local time.
String dateLabelFor(DateTime date) {
  final now = DateTime.now();
  final t = DateTime(date.year, date.month, date.day);
  final n = DateTime(now.year, now.month, now.day);
  if (t == n) return 'Today';
  if (t == n.subtract(const Duration(days: 1))) return 'Yesterday';
  if (t.year == n.year) {
    return DateFormat('MMM d').format(date);
  }
  return DateFormat('MMM d, y').format(date);
}

String shortDowLabel(DateTime date) {
  return DateFormat('EEE').format(date);
}

String longDowLabel(DateTime date) {
  return DateFormat('EEEE').format(date);
}

String fullDateLine(DateTime date) {
  return DateFormat('MMM d, y').format(date);
}

/// Parse YYYY-MM-DD in local.
DateTime parseLocalDate(String ymd) {
  final p = ymd.split('-');
  if (p.length != 3) {
    return DateTime.now();
  }
  return DateTime(
    int.parse(p[0]),
    int.parse(p[1]),
    int.parse(p[2]),
  );
}

String formatYmd(DateTime d) {
  return DateFormat('yyyy-MM-dd').format(d);
}
