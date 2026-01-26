import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_voice_assistant/background_service.dart' show BleBackgroundService, bleBackgroundServiceProvider;
import 'package:nexus_voice_assistant/bg_ble_client.dart' show BleConnectionState;
import 'package:nexus_voice_assistant/services/hardware_service/rtc_service.dart';
import 'package:nexus_voice_assistant/services/hardware_service/battery_service.dart';
import 'package:nexus_voice_assistant/services/logging_service.dart';

/// Riverpod provider for HardwareService
final hardwareServiceProvider = Provider<HardwareService>((ref) {
  final bgService = ref.watch(bleBackgroundServiceProvider);
  return HardwareService(bgService);
});

class HardwareService {
  final BleBackgroundService _bgService;
  BleConnectionState _lastStatus = BleConnectionState.scanning;
  String? _deviceName;

  HardwareService(this._bgService) {
    // Listen to status stream to track connection state
    _bgService.statusStream.listen((status) {
      _lastStatus = status;
    });
    
    // Read device name once during initialization
    _readDeviceName();
  }

  Stream<BleConnectionState> get statusStream => _bgService.statusStream;
  bool get isConnected => _lastStatus == BleConnectionState.connected;
  String? get deviceName => _deviceName;

  Future<void> _readDeviceName() async {
    try {
      _deviceName = await readDeviceName();
    } catch (e) {
      debugPrint('Error reading device name during init: $e');
    }
  }

  /// Read RTC time from device (includes timezone)
  Future<RTCTime?> readRTC() async {
    final rtcData = await _bgService.readRTC();
    if (rtcData == null) return null;
    
    try {
      return RTCTime.fromBytes(rtcData);
    } catch (e) {
      debugPrint('Error parsing RTC data: $e');
      return null;
    }
  }

  /// Write RTC time to device
  Future<bool> writeRTC(RTCTime time) async {
    final data = time.toBytes();
    debugPrint('RTC time to write: ${data.toString()}');
    return await _bgService.writeRTC(data);
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
    debugPrint('RTC time to write: ${rtcTime.toString()}');
    return await writeRTC(rtcTime);
  }

  /// Trigger haptic pulse with specified effect ID
  /// @param effectId Effect ID (0-123, where 0 = stop, 1-123 = predefined effects)
  /// @return true on success, false on failure
  Future<bool> triggerHapticPulse({int effectId = 16}) async {
    return await _bgService.writeHaptic(effectId);
  }

  /// Read device name from device
  /// @return Device name string, or null on failure
  Future<String?> readDeviceName() async {
    return await _bgService.readDeviceName();
  }

  /// Write device name to device
  /// @param name Device name to set (max 19 characters)
  /// @return true on success, false on failure
  Future<bool> writeDeviceName(String name) async {
    return await _bgService.writeDeviceName(name);
  }

  /// Read battery data from device (percentage, voltage, and charging status)
  Future<BatteryData?> readBattery() async {
    final batteryData = await _bgService.readBattery();
    if (batteryData == null) return null;

    try {
      if (batteryData.length >= 4) {
        // Format: [voltage_msb, voltage_lsb, soc_percent, charging_status]
        final voltageMsb = batteryData[0];
        final voltageLsb = batteryData[1];
        final socPercent = batteryData[2];
        final chargingStatus = batteryData[3];
        
        // Calculate voltage: (msb << 8) | lsb, then divide by 1000 to get volts (raw is in mV)
        final voltageRaw = (voltageMsb << 8) | voltageLsb;
        final voltage = voltageRaw / 1000.0;
        
        // Charging status: 1 = charging, 0 = not charging
        final isCharging = chargingStatus != 0;
        
        return BatteryData(
          percentage: socPercent,
          voltage: voltage,
          isCharging: isCharging,
        );
      } else if (batteryData.length >= 3) {
        // Backward compatibility: old format without charging status
        final voltageMsb = batteryData[0];
        final voltageLsb = batteryData[1];
        final socPercent = batteryData[2];
        
        final voltageRaw = (voltageMsb << 8) | voltageLsb;
        final voltage = voltageRaw / 1000.0;
        
        return BatteryData(
          percentage: socPercent,
          voltage: voltage,
          isCharging: false,  // Default to not charging for old format
        );
      }
    } catch (e) {
      debugPrint('Error parsing battery data: $e');
    }
    return null;
  }

  // ============================================================================
  // FILE TRANSFER METHODS (COMMENTED OUT)
  // ============================================================================

  // /// Send file request command (triggers file receive with all logic in BLEFileTransport)
  // Future<void> sendFileRequest(String path) async {
  //   // TODO: Implement using background service file methods
  //   // await _bgService.sendFileRequest(path);
  // }

  // /// Send list files request command
  // Future<void> sendListFilesRequest({String? path}) async {
  //   // TODO: Implement using background service file methods
  //   // await _bgService.sendListFilesRequest(path: path);
  // }

  // /// Write file RX data
  // Future<bool> writeFileRx(Uint8List data) async {
  //   return await _bgService.writeFileRx(data);
  // }

  // /// Read file control
  // Future<Uint8List?> readFileCtrl() async {
  //   return await _bgService.readFileCtrl();
  // }

  // /// Write file control
  // Future<bool> writeFileCtrl(Uint8List data) async {
  //   return await _bgService.writeFileCtrl(data);
  // }

  // /// Get file TX stream
  // Stream<Uint8List> get fileTxStream => _bgService.fileTxStream;
}
