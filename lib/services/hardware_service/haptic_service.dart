import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:nexus_voice_assistant/services/ble_service/ble_service.dart';
import 'package:nexus_voice_assistant/services/logging_service.dart';

class HapticService {
  final BLEService _bleService;

  HapticService(this._bleService);

  /// Trigger haptic pulse with specified effect ID
  /// @param effectId Effect ID (0-123, where 0 = stop, 1-123 = predefined effects)
  /// @return true on success, false on failure
  Future<bool> triggerHapticPulse({int effectId = 16}) async {
    final hapticCharacteristic = _bleService.hapticCharacteristic;
    if (!_bleService.isConnected || hapticCharacteristic == null) {
      LoggingService.instance.log('Cannot trigger haptic pulse: not connected or characteristic not available');
      return false;
    }

    try {
      // Write 1-byte effect ID to haptic characteristic
      final data = Uint8List.fromList([effectId]);
      await hapticCharacteristic.write(data, withoutResponse: true);
      LoggingService.instance.log('Haptic pulse triggered with effect ID: $effectId');
      return true;
    } catch (e) {
      LoggingService.instance.log('Error triggering haptic pulse: $e');
      return false;
    }
  }
}

