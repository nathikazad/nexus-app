import 'package:nx_db/nx_db.dart';

/// Reads a datetime attribute from [Model.attributes] (map or parsed JSON).
DateTime? readWallClockDateTimeAttr(Model m, String key) {
  final raw = m.attributes?[key];
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}
