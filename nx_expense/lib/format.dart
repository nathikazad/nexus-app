import 'package:intl/intl.dart';

final _money = NumberFormat.currency(symbol: '\$');
final _dateTime = DateFormat.yMMMd();
final _dateTimeFull = DateFormat.yMMMd().add_jm();

String formatMoney(num? n) {
  if (n == null) return '—';
  return _money.format(n);
}

String formatModelDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return _dateTime.format(d.toLocal());
  } catch (_) {
    return iso;
  }
}

String formatModelDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return _dateTimeFull.format(d.toLocal());
  } catch (_) {
    return iso;
  }
}
