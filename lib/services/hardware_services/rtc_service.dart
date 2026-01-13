import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../ble_service.dart';

/// RTC time structure
class RTCTime {
  final int seconds;   // 0-59
  final int minutes;   // 0-59
  final int hours;     // 0-23
  final int weekday;  // 1-7 (1=Monday, 7=Sunday)
  final int date;      // 1-31
  final int month;     // 1-12
  final int year;      // 0-99 (offset from 2000)
  final int timezoneHours;   // -12 to +14 (UTC offset hours)
  final int timezoneMinutes; // 0, 30, or 45 (UTC offset minutes)

  RTCTime({
    required this.seconds,
    required this.minutes,
    required this.hours,
    required this.weekday,
    required this.date,
    required this.month,
    required this.year,
    this.timezoneHours = -8,   // Default PST
    this.timezoneMinutes = 0,
  });

  /// Create from 9-byte BLE data (or 7-byte for backward compatibility)
  /// Format: [seconds, minutes, hours, weekday, date, month, year, timezone_hours, timezone_minutes]
  factory RTCTime.fromBytes(Uint8List data) {
    if (data.length < 7) {
      throw ArgumentError('RTC data must be at least 7 bytes');
    }
    int tzHours = -8;   // Default PST
    int tzMinutes = 0;
    
    // If 9 bytes, include timezone
    if (data.length >= 9) {
      tzHours = _signedFromUnsigned(data[7]);
      tzMinutes = _signedFromUnsigned(data[8]);
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
    );
  }

  /// Convert signed byte (-128 to 127) from unsigned (0-255)
  static int _signedFromUnsigned(int unsigned) {
    return (unsigned > 127) ? unsigned - 256 : unsigned;
  }

  /// Convert to 9-byte BLE data
  /// Format: [seconds, minutes, hours, weekday, date, month, year, timezone_hours, timezone_minutes]
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
    ]);
  }

  /// Convert signed byte (-128 to 127) to unsigned (0-255)
  static int _unsignedFromSigned(int signed) {
    return signed < 0 ? signed + 256 : signed;
  }

  /// Format as string: "2024-01-15 14:30:45"
  @override
  String toString() {
    final fullYear = 2000 + year;
    return '${fullYear.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${date.toString().padLeft(2, '0')} '
        '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  /// Format for display: "MM/DD/YY\nhh:mm am/pm"
  String toDisplayString() {
    final shortYear = year % 100;
    final monthStr = month.toString().padLeft(2, '0');
    final dateStr = date.toString().padLeft(2, '0');
    final yearStr = shortYear.toString().padLeft(2, '0');
    
    // Convert to 12-hour format
    final hour12 = hours == 0 ? 12 : (hours > 12 ? hours - 12 : hours);
    final amPm = hours < 12 ? 'am' : 'pm';
    final hourStr = hour12.toString().padLeft(2, '0');
    final minuteStr = minutes.toString().padLeft(2, '0');
    
    return '$monthStr/$dateStr/$yearStr\n$hourStr:$minuteStr $amPm';
  }

  /// Create from DateTime (uses system timezone offset)
  factory RTCTime.fromDateTime(DateTime dateTime, {int? timezoneHours, int? timezoneMinutes}) {
    return RTCTime(
      seconds: dateTime.second,
      minutes: dateTime.minute,
      hours: dateTime.hour,
      weekday: dateTime.weekday, // DateTime.weekday is 1=Monday, 7=Sunday
      date: dateTime.day,
      month: dateTime.month,
      year: dateTime.year - 2000,
      timezoneHours: timezoneHours ?? -8,   // Default PST if not provided
      timezoneMinutes: timezoneMinutes ?? 0,
    );
  }
  
  /// Get timezone string (e.g., "UTC-8:00")
  String getTimezoneString() {
    final sign = timezoneHours >= 0 ? '+' : '';
    return 'UTC$sign$timezoneHours:${timezoneMinutes.toString().padLeft(2, '0')}';
  }

  /// Convert to DateTime
  DateTime toDateTime() {
    return DateTime(2000 + year, month, date, hours, minutes, seconds);
  }
}

class RTCService {
  final BLEService _bleService;

  RTCService(this._bleService);

  /// Read RTC time from device (includes timezone)
  Future<RTCTime?> readRTC() async {
    final rtcCharacteristic = _bleService.rtcCharacteristic;
    if (!_bleService.isConnected || rtcCharacteristic == null) {
      return null;
    }

    try {
      final data = await rtcCharacteristic.read();
      if (data.length >= 7) {
        // Accept 7 bytes (backward compatibility) or 9 bytes (with timezone)
        return RTCTime.fromBytes(Uint8List.fromList(data));
      }
    } catch (e) {
      debugPrint('Error reading RTC: $e');
    }
    return null;
  }

  /// Write RTC time to device
  Future<bool> writeRTC(RTCTime time) async {
    final rtcCharacteristic = _bleService.rtcCharacteristic;
    if (!_bleService.isConnected || rtcCharacteristic == null) {
      return false;
    }
    // print time
    debugPrint('RTC time to write: ${time.toString()}');
    try {
      final data = time.toBytes();
      await rtcCharacteristic.write(data, withoutResponse: false);
      debugPrint('RTC time written: ${time.toString()}');
      return true;
    } catch (e) {
      debugPrint('Error writing RTC: $e');
      return false;
    }
  }

  /// Set RTC time from current system time (preserves existing timezone)
  Future<bool> setRTCTimeNow() async {
    // Read current RTC to get timezone
    final currentRTC = await readRTC();
    final now = DateTime.now();
    
    // Preserve timezone from current RTC, or use default PST
    final rtcTime = RTCTime.fromDateTime(
      now,
      timezoneHours: currentRTC?.timezoneHours ?? -8,
      timezoneMinutes: currentRTC?.timezoneMinutes ?? 0,
    );
    return await writeRTC(rtcTime);
  }
}

