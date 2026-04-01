import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_voice_assistant/background_service.dart' show BleBackgroundService, bleBackgroundServiceProvider;
import 'package:nexus_voice_assistant/bg_ble_client.dart' show BleConnectionState;
import 'package:nexus_voice_assistant/services/hardware_service/camera_command.dart';
import 'package:nexus_voice_assistant/services/hardware_service/rtc_service.dart';
import 'package:nexus_voice_assistant/services/paired_device_storage.dart';


/// Auto photo-record status from device (GATT read).
class CameraRecordStatus {
  final bool isRecording;
  final int periodSec;

  CameraRecordStatus({
    required this.isRecording,
    required this.periodSec,
  });
}

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

/// Riverpod provider for HardwareService
final hardwareServiceProvider = Provider<HardwareService>((ref) {
  final bgService = ref.watch(bleBackgroundServiceProvider);
  return HardwareService(bgService);
});

class HardwareService {
  final BleBackgroundService _bgService;
  String? _deviceName;
  final StreamController<CameraRecordStatus> _cameraStatusController = StreamController<CameraRecordStatus>.broadcast();

  HardwareService(this._bgService) {
    // Listen to device.push for camera status updates
    _bgService.devicePushStream.listen((event) {
      if (event['type'] == 'camera') {
        final data = event['data'] as Map<String, dynamic>?;
        if (data != null) {
          final isRecording = data['isRecording'] as bool? ?? false;
          final periodSec = (data['periodSec'] as int?)?.clamp(1, 1000) ?? 60;
          _cameraStatusController.add(CameraRecordStatus(
            isRecording: isRecording,
            periodSec: periodSec,
          ));
        }
      }
    });
    
    // Read device name once during initialization
    _readDeviceName();
  }

  Stream<BleConnectionState> get statusStream => _bgService.statusStream;
  Stream<CameraRecordStatus> get cameraStatusStream => _cameraStatusController.stream;
  bool get isConnected => _bgService.lastKnownBleStatus == BleConnectionState.connected;
  String? get deviceName => _deviceName;

  /// Saved BLE peripheral id ([BluetoothDevice.remoteId]), or null until the user picks a device.
  Future<String?> getPairedRemoteId() => PairedDeviceStorage.getPairedRemoteId();

  /// Persists the chosen device and starts background connect (call after UI selection).
  Future<void> savePairedRemoteIdAndConnect(String remoteId) async {
    await PairedDeviceStorage.setPairedRemoteId(remoteId);
    _bgService.applyPairedRemoteId(remoteId);
  }

  /// Clears storage and stops BLE reconnect to any peripheral.
  Future<void> forgetPairedDevice() async {
    await PairedDeviceStorage.clearPairedRemoteId();
    _bgService.clearPairedRemoteId();
  }

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

  /// Send a camera command to the device.
  /// For [CameraCommand.setRecordPeriod], [period] must be 1-1000.
  /// @return true on success, false on failure
  Future<bool> sendCameraCommand(CameraCommand command, {int? period}) async {
    final data = command.toBytes(period: period);
    return await _bgService.writeCamera(data);
  }

  /// Read auto photo-record status (poll; device does not notify).
  Future<CameraRecordStatus?> readCameraRecordStatus() async {
    final st = await _bgService.readCameraStatus();
    if (st == null) return null;
    return CameraRecordStatus(isRecording: st.$1, periodSec: st.$2);
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

}
