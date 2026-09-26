import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../ble/bg_ble_client.dart';
import '../hardware/camera_command.dart';
import 'necklace_device_port.dart';

/// Device tool semantics, independent of sockets and isolate lifecycle.
class NecklaceCommandHandler {
  NecklaceCommandHandler(this.device);
  final NecklaceDevicePort device;
  Future<String?> handle(
      int requestId, String action, Map<String, dynamic> params) async {
    try {
      switch (action) {
        case 'take_photo':
          final success =
              await device.writeCamera(CameraCommand.capture.toBytes());
          return jsonEncode({'success': success});
        case 'get_camera_status':
          final st = await device.readCameraStatus();
          if (st == null) return jsonEncode({'success': false});
          final (isRecording, periodSec) = st;
          return jsonEncode({
            'success': true,
            'isRecording': isRecording,
            'periodSec': periodSec,
          });
        case 'start_record':
          final periodSec = (params['periodSec'] as num?)?.toInt() ?? 60;
          final periodOk = await device.writeCamera(
            CameraCommand.setRecordPeriod
                .toBytes(period: periodSec.clamp(1, 1000)),
          );
          if (!periodOk) return jsonEncode({'success': false});
          final startOk =
              await device.writeCamera(CameraCommand.startRecord.toBytes());
          return jsonEncode({'success': startOk});
        case 'stop_record':
          final success =
              await device.writeCamera(CameraCommand.stopRecord.toBytes());
          return jsonEncode({'success': success});
        case 'set_record_period':
          final periodSec = (params['periodSec'] as num?)?.toInt();
          if (periodSec == null || periodSec < 1 || periodSec > 1000) {
            return jsonEncode(
                {'success': false, 'error': 'periodSec required (1-1000)'});
          }
          final success = await device.writeCamera(
            CameraCommand.setRecordPeriod.toBytes(period: periodSec),
          );
          return jsonEncode({'success': success});
        case 'get_battery':
          final raw = await device.readBattery();
          final parsed = raw != null ? BleClient.parseBatteryStatus(raw) : null;
          if (parsed == null) {
            return jsonEncode(
                {'success': false, 'error': 'battery unavailable'});
          }
          final (:voltageMv, :percent, :charging, :timeIso, :timezone) = parsed;
          final out = <String, dynamic>{
            'success': true,
            'voltageMv': voltageMv,
            'percent': percent,
            'charging': charging,
          };
          if (timeIso != null) out['time'] = timeIso;
          if (timezone != null) out['timezone'] = timezone;
          return jsonEncode(out);
        case 'vibrate':
          final effectId =
              ((params['effectId'] as num?)?.toInt() ?? 16).clamp(0, 123);
          final success = await device.writeHaptic(effectId);
          return jsonEncode({'success': success});
        case 'power_cycle':
          final success =
              await device.writeCamera(CameraCommand.powerCycle.toBytes());
          return jsonEncode({'success': success});
        default:
          return null;
      }
    } catch (e) {
      debugPrint("[BLE BG] Device request $action error: $e");
      return jsonEncode({'success': false, 'error': e.toString()});
    }
  }
}
