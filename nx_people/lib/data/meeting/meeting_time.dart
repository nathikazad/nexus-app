/// Model creation timestamps are stored as UTC, including values without a suffix.
DateTime? parseMeetingCreatedAt(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final text = value.trim();
  final hasZone = RegExp(
    r'(Z|[+-]\d{2}:?\d{2})$',
    caseSensitive: false,
  ).hasMatch(text);
  return DateTime.tryParse(hasZone ? text : '${text}Z');
}

String shortMonth(DateTime date) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][date.month - 1];

String weekRange(DateTime start) {
  final end = DateTime(start.year, start.month, start.day + 6);
  if (start.year != end.year) {
    return '${shortMonth(start)} ${start.day}, ${start.year} – ${shortMonth(end)} ${end.day}, ${end.year}';
  }
  if (start.month != end.month) {
    return '${shortMonth(start)} ${start.day} – ${shortMonth(end)} ${end.day}';
  }
  return '${shortMonth(start)} ${start.day} – ${end.day}';
}
