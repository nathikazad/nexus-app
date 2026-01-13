import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:nexus_voice_assistant/services/openai_service.dart';
import '../services/ble_service.dart';
import '../util/ble_audio_transport.dart';

/// Battery data structure
class BatteryData {
  final int percentage;  // 0-100
  final double voltage;  // Voltage in volts
  final bool isCharging;  // Whether battery is charging

  BatteryData({
    required this.percentage,
    required this.voltage,
    required this.isCharging,
  });
}

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

class HardwareService {
  static final HardwareService _instance = HardwareService._internal();
  
  /// Singleton instance getter
  static HardwareService get instance => _instance;
  
  factory HardwareService() => _instance;
  HardwareService._internal();

  final BLEService _bleService = BLEService.instance;
  
  // Audio transport
  BLEAudioTransport? _audioTransport;
  
  StreamSubscription<bool>? _connectionStateSubscription;
  
  StreamController<BatteryData>? _batteryController; // Battery data (percentage and voltage)
  Timer? _batteryPollTimer;
  
  bool _isInitialized = false;

  Stream<BatteryData>? get batteryStream => _batteryController?.stream;
  bool get isInitialized => _isInitialized;
  
  bool get isPaused => _audioTransport?.isPaused ?? false;
  
  // Device name getter
  String? get deviceName {
    final device = _bleService.currentDevice;
    if (device == null) return null;
    final name = device.platformName.isNotEmpty 
        ? device.platformName 
        : device.advName;
    // If name starts with "Nexus-", return it as-is, otherwise format from MAC
    if (name.startsWith('Nexus-')) {
      return name;
    }
    // Extract last 5 chars of MAC address
    final macStr = device.remoteId.toString();
    // MAC format: "XX:XX:XX:XX:XX:XX" or similar, extract last 5 hex chars
    final macParts = macStr.replaceAll(':', '').replaceAll('-', '').toUpperCase();
    if (macParts.length >= 5) {
      final last5 = macParts.substring(macParts.length - 5);
      return 'Nexus-$last5';
    }
    return name;
  }


  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Wait for BLE service to be initialized
      await _bleService.initialize();
      
      // Initialize audio transport with callbacks and dependencies
      _audioTransport = BLEAudioTransport(
        onPcm24Chunk: (pcm24Chunk) {
          OpenAIService.instance.sendAudio(pcm24Chunk, queryOrigin.Hardware);
        },
        onEof: () {
          OpenAIService.instance.createResponse();
        },
        openAiAudioOutStream: OpenAIService.instance.hardWareAudioOutStream,
        isConnected: () => _bleService.isConnected,
        getMTU: () => _bleService.getMTU(),
      );
      
      // Initialize audio processing pipeline (includes packet queue, stream subscriptions, and OpenAI relayer)
      _audioTransport!.initializeAudioProcessing();
      
      // Initialize battery controller
      _batteryController = StreamController<BatteryData>.broadcast();
      
      // Listen for connection state changes to manage battery polling
      final connectionStateStream = _bleService.connectionStateStream;
      if (connectionStateStream != null) {
        _connectionStateSubscription = connectionStateStream.listen(
          (isConnected) {
            if (isConnected) {
              _startBatteryPolling();
            } else {
              _stopBatteryPolling();
            }
          },
          onError: (e) {
            debugPrint('HardwareService: Error in connection state stream: $e');
          },
        );
      }
      
      // Start battery polling if already connected
      if (_bleService.isConnected) {
        _startBatteryPolling();
      }
      
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Error initializing HardwareService: $e');
      return false;
    }
  }
  
  /// Get the audio transport instance (for BLEService to access)
  BLEAudioTransport? get audioTransport => _audioTransport;
  
  /// Initialize audio transport characteristics (called from BLEService after connection)
  Future<bool> initAudioTransport(BluetoothService service, String audioTxUuid, String audioRxUuid) async {
    if (_audioTransport == null) {
      debugPrint('Audio transport not initialized');
      return false;
    }
    
    if (!await _audioTransport!.initializeAudioTransportCharacteristics(service, audioTxUuid, audioRxUuid)) {
      debugPrint('Failed to initialize audio TX/RX characteristics');
      return false;
    }
    
    return true;
  }
  
  /// Disconnect audio transport (unsubscribe from notifications and reset pause state)
  Future<void> disconnectAudioTransport() async {
    if (_audioTransport == null) {
      return;
    }
    
    await _audioTransport!.unsubscribeFromNotifications();
    _audioTransport!.resetPauseState();
  }
  
  /// Enqueue a packet to be sent. Packets are batched up to MTU size before being queued.
  void enqueuePacket(Uint8List packet) {
    _audioTransport?.enqueuePacket(packet);
  }

  /// Send EOF to ESP32
  Future<void> sendEOFToEsp32() async {
    await _audioTransport?.sendEOFToEsp32();
  }

  /// Read battery data from device (percentage, voltage, and charging status)
  Future<BatteryData?> readBattery() async {
    final batteryCharacteristic = _bleService.batteryCharacteristic;
    if (!_bleService.isConnected || batteryCharacteristic == null) {
      return null;
    }

    try {
      final data = await batteryCharacteristic.read();
      if (data.length >= 4) {
        // Format: [voltage_msb, voltage_lsb, soc_percent, charging_status]
        final voltageMsb = data[0];
        final voltageLsb = data[1];
        final socPercent = data[2];
        final chargingStatus = data[3];
        
        // Calculate voltage: (msb << 8) | lsb, then divide by 1000 to get volts (raw is in mV)
        final voltageRaw = (voltageMsb << 8) | voltageLsb;
        final voltage = voltageRaw / 1000.0;
        
        // Charging status: 1 = charging, 0 = not charging
        final isCharging = chargingStatus != 0;
        
        final batteryData = BatteryData(
          percentage: socPercent,
          voltage: voltage,
          isCharging: isCharging,
        );
        
        _batteryController?.add(batteryData);
        return batteryData;
      } else if (data.length >= 3) {
        // Backward compatibility: old format without charging status
        final voltageMsb = data[0];
        final voltageLsb = data[1];
        final socPercent = data[2];
        
        final voltageRaw = (voltageMsb << 8) | voltageLsb;
        final voltage = voltageRaw / 1000.0;
        
        final batteryData = BatteryData(
          percentage: socPercent,
          voltage: voltage,
          isCharging: false,  // Default to not charging for old format
        );
        
        _batteryController?.add(batteryData);
        return batteryData;
      }
    } catch (e) {
      debugPrint('Error reading battery: $e');
    }
    return null;
  }
  
  void _startBatteryPolling() {
    _stopBatteryPolling(); // Stop any existing timer
    
    final batteryCharacteristic = _bleService.batteryCharacteristic;
    if (!_bleService.isConnected || batteryCharacteristic == null) {
      return;
    }
    
    // Read battery immediately
    readBattery();
    
    // Poll every 1 second for real-time updates
    _batteryPollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      readBattery();
    });
  }
  
  void _stopBatteryPolling() {
    _batteryPollTimer?.cancel();
    _batteryPollTimer = null;
  }

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

  /// Trigger haptic pulse with specified effect ID
  /// @param effectId Effect ID (0-123, where 0 = stop, 1-123 = predefined effects)
  /// @return true on success, false on failure
  Future<bool> triggerHapticPulse() async {
    final hapticCharacteristic = _bleService.hapticCharacteristic;
    if (!_bleService.isConnected || hapticCharacteristic == null) {
      debugPrint('Cannot trigger haptic pulse: not connected or characteristic not available');
      return false;
    }

 

    try {
      // Write 1-byte effect ID to haptic characteristic
      final data = Uint8List.fromList([16]);
      await hapticCharacteristic.write(data, withoutResponse: true);
      debugPrint('Haptic pulse triggered');
      return true;
    } catch (e) {
      debugPrint('Error triggering haptic pulse: $e');
      return false;
    }
  }

  /// Read device name from device
  /// @return Device name string, or null on failure
  Future<String?> readDeviceName() async {
    final deviceNameCharacteristic = _bleService.deviceNameCharacteristic;
    if (!_bleService.isConnected || deviceNameCharacteristic == null) {
      return null;
    }

    try {
      final data = await deviceNameCharacteristic.read();
      if (data.isNotEmpty) {
        // Convert bytes to string (UTF-8)
        final name = String.fromCharCodes(data);
        debugPrint('Device name read: "$name"');
        return name;
      }
      return null;
    } catch (e) {
      debugPrint('Error reading device name: $e');
      return null;
    }
  }

  /// Write device name to device
  /// @param name Device name to set (max 19 characters)
  /// @return true on success, false on failure
  Future<bool> writeDeviceName(String name) async {
    final deviceNameCharacteristic = _bleService.deviceNameCharacteristic;
    if (!_bleService.isConnected || deviceNameCharacteristic == null) {
      debugPrint('Cannot write device name: not connected or characteristic not available');
      return false;
    }

    // Validate name length (max 19 chars)
    if (name.length >= 20) {
      debugPrint('Device name too long: ${name.length} (max 19)');
      return false;
    }

    try {
      // Convert string to UTF-8 bytes
      final data = Uint8List.fromList(name.codeUnits);
      await deviceNameCharacteristic.write(data, withoutResponse: false);
      debugPrint('Device name written: "$name"');
      return true;
    } catch (e) {
      debugPrint('Error writing device name: $e');
      return false;
    }
  }

  Future<void> dispose() async {
    await _audioTransport?.dispose();
    await _connectionStateSubscription?.cancel();
    
    _stopBatteryPolling();
    await _batteryController?.close();
    
    _connectionStateSubscription = null;
    _batteryController = null;
    _audioTransport = null;
    _isInitialized = false;
  }
}

