import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;

/// Legacy necklace device request framing. Recognized control frames are always
/// consumed, even if malformed, so they cannot be mistaken for Opus.
class NecklaceDeviceProtocol {
  static const _DEVICE_REQUEST = 4;

  /// Handle DEVICE_REQUEST from server. Returns true if handled (don't forward to BLE).
  Future<bool> handle(
    Uint8List message, {
    required bool Function() isCurrent,
    required void Function(int, String) respond,
    Future<String?> Function(int, String, Map<String, dynamic>)?
        onDeviceRequest,
  }) async {
    if (message.length < 6) return false;
    final byteData = ByteData.view(
        message.buffer, message.offsetInBytes, message.lengthInBytes);
    final headerType = byteData.getUint16(4, Endian.little);
    if (headerType != _DEVICE_REQUEST) return false;
    // Recognized control frames are consumed even when malformed or unsupported.
    if (message.length < 12) return true;

    final requestId = byteData.getUint32(6, Endian.little);
    final payloadSize = byteData.getUint16(10, Endian.little);
    if (message.length != 12 + payloadSize) return true;

    try {
      final payloadStr = utf8.decode(message.sublist(12, 12 + payloadSize));
      final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
      final action = payload['action'] as String?;
      if (action == null) return true;

      if (action == 'get_gps') {
        // Fake GPS: always return same coordinates (SF)
        final result = jsonEncode({
          'lat': 37.7749,
          'lng': -122.4194,
          'accuracy': 10.0,
        });
        respond(requestId, result);
        debugPrint("[Socket] Handled get_gps request, sent fake GPS");
        return true;
      }

      const deviceActions = [
        'audio.start', 'audio.stop', 'audio.new',
        'take_photo',
        'get_camera_status',
        'start_record',
        'stop_record',
        'set_record_period',
        'get_battery',
        'vibrate',
        'power_cycle',
      ];
      if (deviceActions.contains(action) && onDeviceRequest != null) {
        final result = await onDeviceRequest(requestId, action, payload);
        if (!isCurrent()) return true;
        if (result != null) {
          respond(requestId, result);
          debugPrint("[Socket] Handled $action request via onDeviceRequest");
          return true;
        }
      }
    } catch (e) {
      debugPrint("[Socket] Error handling device request: $e");
    }
    if (isCurrent()) {
      respond(
          requestId,
          jsonEncode({
            'success': false,
            'error': 'Unsupported or failed device request'
          }));
    }
    return true;
  }
}
