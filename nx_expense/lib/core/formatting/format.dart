import 'package:intl/intl.dart';

final _money = NumberFormat.currency(symbol: '\$');
final _dateTime = DateFormat.yMMMd();
final _dateTimeFull = DateFormat.yMMMd().add_jm();

String formatMoney(num? n) {
  if (n == null) return '—';
  return _money.format(n);
}

/// Parses leading `YYYY-MM-DD` as a **calendar** date (no timezone shift).
DateTime? tryParseYmdLocal(String? s) {
  if (s == null || s.isEmpty) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s.trim());
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  return DateTime(y, mo, d);
}

/// Initial [DateTime] for [showDatePicker] from stored `YYYY-MM-DD` or ISO datetime.
DateTime initialDateForYmdOrIso(String text) {
  final ymd = tryParseYmdLocal(text);
  if (ymd != null) return ymd;
  try {
    final t = text.trim();
    final p = DateTime.parse(t);
    if (t.endsWith('Z')) {
      final u = p.toUtc();
      return DateTime(u.year, u.month, u.day);
    }
    return DateTime(p.year, p.month, p.day);
  } catch (_) {
    return DateTime.now();
  }
}

/// Normalize a `date` attribute to `YYYY-MM-DD` for sorting (mixed plain vs ISO-Z strings).
String normalizeDateAttributeSortKey(String raw) {
  final t = raw.trim();
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(t)) return t;
  try {
    final d = DateTime.parse(t);
    if (t.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(t)) {
      final u = d.toUtc();
      return '${u.year.toString().padLeft(4, '0')}-${u.month.toString().padLeft(2, '0')}-${u.day.toString().padLeft(2, '0')}';
    }
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  } catch (_) {
    return t;
  }
}

/// Display a model `date` / timestamp: **calendar** dates without off-by-one from `toLocal()`.
String formatModelDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final t = iso.trim();
  try {
    final plain = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(t);
    if (plain != null) {
      final y = int.parse(plain.group(1)!);
      final m = int.parse(plain.group(2)!);
      final d = int.parse(plain.group(3)!);
      return _dateTime.format(DateTime(y, m, d));
    }
    final parsed = DateTime.parse(t);
    if (t.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(t)) {
      final u = parsed.toUtc();
      return _dateTime.format(DateTime(u.year, u.month, u.day));
    }
    return _dateTime.format(DateTime(parsed.year, parsed.month, parsed.day));
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

/// Read-only attribute display: booleans, money, and datetime as **date only** (no time).
String formatDisplayAttributeValue(dynamic v, String? valueType) {
  if (v == null) return '—';
  if (v is bool) return v ? 'Yes' : 'No';
  if (v is num) return formatMoney(v);
  final s = v.toString();
  if (valueType == 'datetime') return formatModelDate(s);
  return s;
}
