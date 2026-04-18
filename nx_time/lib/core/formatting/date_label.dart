import 'package:intl/intl.dart';

/// "Today — Sat, Apr 18" style title for the Today header.
String todayTitleLine(DateTime dayLocal) {
  return 'Today — ${DateFormat('EEE, MMM d').format(dayLocal)}';
}
