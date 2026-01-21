import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:nexus_voice_assistant/services/ble_service/ble_service.dart';
import 'package:nexus_voice_assistant/services/logging_service.dart';

class NameService {
  final BLEService _bleService;

  NameService(this._bleService);

  /// Get device name (formatted from device info or MAC address)
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
        LoggingService.instance.log('Device name read: "$name"');
        return name;
      }
      return null;
    } catch (e) {
      LoggingService.instance.log('Error reading device name: $e');
      return null;
    }
  }

  /// Write device name to device
  /// @param name Device name to set (max 19 characters)
  /// @return true on success, false on failure
  Future<bool> writeDeviceName(String name) async {
    final deviceNameCharacteristic = _bleService.deviceNameCharacteristic;
    if (!_bleService.isConnected || deviceNameCharacteristic == null) {
      LoggingService.instance.log('Cannot write device name: not connected or characteristic not available');
      return false;
    }

    // Validate name length (max 19 chars)
    if (name.length >= 20) {
      LoggingService.instance.log('Device name too long: ${name.length} (max 19)');
      return false;
    }

    try {
      // Convert string to UTF-8 bytes
      final data = Uint8List.fromList(name.codeUnits);
      await deviceNameCharacteristic.write(data, withoutResponse: false);
      LoggingService.instance.log('Device name written: "$name"');
      return true;
    } catch (e) {
      LoggingService.instance.log('Error writing device name: $e');
      return false;
    }
  }
}

