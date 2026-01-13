import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Handles audio RX/TX characteristic communication for BLE
class BLEAudioTransport {
  // Signal constants
  static const int signalEof = 0xFFFC;
  static const int signalPause = 0xFFFE;
  static const int signalResume = 0xFFFD;
  static const int signalAudioPacket = 0x0001;
  
  BluetoothCharacteristic? _audioTxCharacteristic;
  BluetoothCharacteristic? _audioRxCharacteristic;
  StreamSubscription? _notificationSubscription;
  
  // Callbacks for data handling
  final void Function(Uint8List)? onOpusPacket;
  final void Function()? onEof;
  final void Function(bool)? onPauseStateChanged;
  
  bool _paused = false;
  
  BLEAudioTransport({
    this.onOpusPacket,
    this.onEof,
    this.onPauseStateChanged,
  });
  
  /// Initialize audio TX and RX characteristics from discovered service
  bool initializeCharacteristics(BluetoothService service, String audioTxUuid, String audioRxUuid) {
    _audioTxCharacteristic = null;
    _audioRxCharacteristic = null;
    
    for (BluetoothCharacteristic char in service.characteristics) {
      if (char.uuid.toString().toLowerCase() == audioTxUuid.toLowerCase()) {
        _audioTxCharacteristic = char;
        debugPrint('Found Audio TX characteristic');
      } else if (char.uuid.toString().toLowerCase() == audioRxUuid.toLowerCase()) {
        _audioRxCharacteristic = char;
        debugPrint('Found Audio RX characteristic');
      }
    }
    
    return _audioTxCharacteristic != null && _audioRxCharacteristic != null;
  }
  
  /// Subscribe to audio TX notifications (incoming data from ESP32)
  Future<bool> subscribeToNotifications() async {
    if (_audioTxCharacteristic == null) {
      return false;
    }
    
    try {
      await _audioTxCharacteristic!.setNotifyValue(true);
      _notificationSubscription = _audioTxCharacteristic!.lastValueStream.listen(
        _handleNotification,
        onError: (error) {
          debugPrint('Notification error: $error');
        },
      );
      debugPrint('Subscribed to audio notifications');
      return true;
    } catch (e) {
      debugPrint('Error subscribing to notifications: $e');
      return false;
    }
  }
  
  /// Unsubscribe from audio TX notifications
  Future<void> unsubscribeFromNotifications() async {
    if (_audioTxCharacteristic != null) {
      try {
        await _audioTxCharacteristic!.setNotifyValue(false);
      } catch (e) {
        debugPrint('Error unsubscribing: $e');
      }
    }
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
  }
  
  /// Handle incoming notifications from audio TX characteristic
  void _handleNotification(List<int> data) {
    if (data.isEmpty) return;

    try {
      Uint8List bytes = Uint8List.fromList(data);
      int offset = 0;

      // Parse multi-frame packets
      while (offset + 2 <= bytes.length) {
        // Read identifier (2 bytes, little-endian)
        int identifier = bytes[offset] | (bytes[offset + 1] << 8);
        offset += 2;

        // Handle flow control signals
        if (identifier == signalPause) {
          debugPrint('[FLOW] Received PAUSE signal (0xFFFE) - pausing transmission');
          _paused = true;
          onPauseStateChanged?.call(_paused);
          continue;
        }
        if (identifier == signalResume) {
          debugPrint('[FLOW] Received RESUME signal (0xFFFD) - resuming transmission');
          _paused = false;
          onPauseStateChanged?.call(_paused);
          continue;
        }

        // Handle EOF
        if (identifier == signalEof) {
          debugPrint('[UPLOAD] Received EOF');
          onEof?.call();
          continue;
        }

        // Handle audio packet
        if (identifier == signalAudioPacket) {
          debugPrint('[UPLOAD] Received AUDIO PACKET');
          // Read packet size (2 bytes, little-endian)
          if (offset + 2 > bytes.length) {
            debugPrint('[WARNING] Incomplete packet size at offset $offset');
            break;
          }
          
          int packetSize = bytes[offset] | (bytes[offset + 1] << 8);
          offset += 2;

          // Check if we have complete packet
          if (offset + packetSize > bytes.length) {
            debugPrint('[WARNING] Incomplete packet at offset $offset');
            break;
          }

          // Extract Opus data
          Uint8List opusData = bytes.sublist(offset, offset + packetSize);
          offset += packetSize;

          // Emit Opus packet
          onOpusPacket?.call(opusData);
        } else {
          debugPrint('[WARNING] Unknown packet identifier: 0x${identifier.toRadixString(16).padLeft(4, '0')}');
          // Try to recover by skipping to next potential packet
          if (offset + 2 <= bytes.length) {
            offset += 2;
          } else {
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('Error handling notification: $e');
    }
  }
  
  /// Get audio RX characteristic for external use (e.g., PacketQueue)
  BluetoothCharacteristic? get audioRxCharacteristic => _audioRxCharacteristic;
  
  /// Get pause state
  bool get isPaused => _paused;
  
  /// Reset pause state
  void resetPauseState() {
    _paused = false;
  }
  
  /// Dispose resources
  Future<void> dispose() async {
    await unsubscribeFromNotifications();
    _audioTxCharacteristic = null;
    _audioRxCharacteristic = null;
  }
}

