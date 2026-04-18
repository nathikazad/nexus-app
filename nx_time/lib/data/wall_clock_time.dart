import 'package:nx_db/nx_db.dart';

/// Reads a datetime attribute from [Model.attributes] (map or parsed JSON).
DateTime? readWallClockDateTimeAttr(Model m, String key) {
  final raw = m.attributes?[key];
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}

/// Interprets DB datetimes as **local wall clock** (no offset shift).
///
/// GraphQL/JSON often returns `...Z` even when the stored instant is meant as local civil time.
DateTime asStoredLocalWallClock(DateTime dt) {
  if (dt.isUtc) {
    return DateTime(
      dt.year,
      dt.month,
      dt.day,
      dt.hour,
      dt.minute,
      dt.second,
      dt.millisecond,
      dt.microsecond,
    );
  }
  return dt;
}
