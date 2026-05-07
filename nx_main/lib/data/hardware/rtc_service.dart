import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// RTC time structure
class RTCTime {
  final int seconds; // 0-59
  final int minutes; // 0-59
  final int hours; // 0-23
  final int weekday; // 1-7 (1=Monday, 7=Sunday)
  final int date; // 1-31
  final int month; // 1-12
  final int year; // 0-99 (offset from 2000)
  final int timezoneHours; // -12 to +14 (UTC offset hours)
  final int timezoneMinutes; // 0, 30, or 45 (UTC offset minutes)
  final int millisecond; // 0-999, optional BLE extension for ms-accurate sync

  RTCTime({
    required this.seconds,
    required this.minutes,
    required this.hours,
    required this.weekday,
    required this.date,
    required this.month,
    required this.year,
    this.timezoneHours = -8, // Default PST
    this.timezoneMinutes = 0,
    this.millisecond = 0,
  });

  /// Create from 11-byte BLE data (or 9/7-byte for backward compatibility)
  /// Format: [seconds, minutes, hours, weekday, date, month, year, timezone_hours, timezone_minutes, millisecond_le16]
  factory RTCTime.fromBytes(Uint8List data) {
    if (data.length < 7) {
      throw ArgumentError('RTC data must be at least 7 bytes');
    }
    int tzHours = -8; // Default PST
    int tzMinutes = 0;
    int millisecond = 0;

    // If 9 bytes, include timezone
    if (data.length >= 9) {
      tzHours = _signedFromUnsigned(data[7]);
      tzMinutes = _signedFromUnsigned(data[8]);
    }
    if (data.length >= 11) {
      millisecond = data[9] | (data[10] << 8);
    }

    return RTCTime(
      seconds: data[0],
      minutes: data[1],
      hours: data[2],
      weekday: data[3],
      date: data[4],
      month: data[5],
      year: data[6],
      timezoneHours: tzHours,
      timezoneMinutes: tzMinutes,
      millisecond: millisecond,
    );
  }

  /// Convert signed byte (-128 to 127) from unsigned (0-255)
  static int _signedFromUnsigned(int unsigned) {
    return (unsigned > 127) ? unsigned - 256 : unsigned;
  }

  /// Convert to 11-byte BLE data.
  /// Format: [seconds, minutes, hours, weekday, date, month, year, timezone_hours, timezone_minutes, millisecond_le16]
  Uint8List toBytes() {
    return Uint8List.fromList([
      seconds,
      minutes,
      hours,
      weekday,
      date,
      month,
      year,
      _unsignedFromSigned(timezoneHours),
      _unsignedFromSigned(timezoneMinutes),
      millisecond & 0xFF,
      (millisecond >> 8) & 0xFF,
    ]);
  }

  /// Convert signed byte (-128 to 127) to unsigned (0-255)
  static int _unsignedFromSigned(int signed) {
    return signed < 0 ? signed + 256 : signed;
  }

  int get _timezoneOffsetMinutes {
    final minuteSign = timezoneHours < 0 ? -1 : 1;
    return timezoneHours * 60 + minuteSign * timezoneMinutes;
  }

  DateTime toUtcDateTime() {
    return DateTime.utc(2000 + year, month, date, hours, minutes, seconds);
  }

  DateTime toLocalWallDateTime() {
    return toUtcDateTime().add(Duration(minutes: _timezoneOffsetMinutes));
  }

  /// Format the raw UTC RTC register value.
  @override
  String toString() {
    final utc = toUtcDateTime();
    final fullYear = utc.year;
    return '${fullYear.toString().padLeft(4, '0')}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')} '
        '${utc.hour.toString().padLeft(2, '0')}:'
        '${utc.minute.toString().padLeft(2, '0')}:'
        '${utc.second.toString().padLeft(2, '0')} UTC';
  }

  /// Format local wall time for display: "MM/DD/YY\nhh:mm am/pm"
  String toDisplayString() {
    final local = toLocalWallDateTime();
    final shortYear = local.year % 100;
    final monthStr = local.month.toString().padLeft(2, '0');
    final dateStr = local.day.toString().padLeft(2, '0');
    final yearStr = shortYear.toString().padLeft(2, '0');

    // Convert to 12-hour format
    final hour12 =
        local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
    final amPm = local.hour < 12 ? 'am' : 'pm';
    final hourStr = hour12.toString().padLeft(2, '0');
    final minuteStr = local.minute.toString().padLeft(2, '0');

    return '$monthStr/$dateStr/$yearStr\n$hourStr:$minuteStr $amPm';
  }

  /// Create from DateTime.
  ///
  /// For device sync, pass UTC [dateTime] fields and the local timezone offset
  /// separately. The nRF RTC registers are UTC; timezone bytes are only for
  /// local display and local file naming on the device.
  factory RTCTime.fromDateTime(DateTime dateTime,
      {int? timezoneHours, int? timezoneMinutes}) {
    final offset = dateTime.timeZoneOffset;
    return RTCTime(
      seconds: dateTime.second,
      minutes: dateTime.minute,
      hours: dateTime.hour,
      weekday: dateTime.weekday, // DateTime.weekday is 1=Monday, 7=Sunday
      date: dateTime.day,
      month: dateTime.month,
      year: dateTime.year - 2000,
      timezoneHours: timezoneHours ?? offset.inHours,
      timezoneMinutes: timezoneMinutes ?? offset.inMinutes.remainder(60).abs(),
      millisecond: dateTime.millisecond,
    );
  }

  /// Get timezone string (e.g., "UTC-8:00")
  String getTimezoneString() {
    final sign = timezoneHours >= 0 ? '+' : '';
    return 'UTC$sign$timezoneHours:${timezoneMinutes.toString().padLeft(2, '0')}';
  }

  /// Convert raw RTC register bytes to a UTC DateTime.
  DateTime toDateTime() {
    return toUtcDateTime();
  }
}
