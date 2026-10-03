bool validBirthday(String value) {
  if (!RegExp(r'^(--|\d{4}-)\d{2}-\d{2}$').hasMatch(value)) return false;
  final full = value.startsWith('--') ? '2000-${value.substring(2)}' : value;
  final d = DateTime.tryParse(full);
  return d != null &&
      d.year >= 1 &&
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}' ==
          full;
}
