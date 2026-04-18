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
