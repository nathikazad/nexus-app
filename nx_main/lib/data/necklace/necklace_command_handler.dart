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
      Uint8List? fileId;
      final rawId = params['file_id'];
      if (rawId != null) {
        if (rawId is! String ||
            !RegExp(r'^[0-9a-f]{32}$').hasMatch(rawId) ||
            rawId == '0' * 32) {
          return jsonEncode({'success': false, 'error': 'Invalid file ID'});
        }
        fileId = Uint8List.fromList(List.generate(16,
            (i) => int.parse(rawId.substring(i * 2, i * 2 + 2), radix: 16)));
      }
      switch (action) {
        case 'audio.start':
        case 'audio.stop':
        case 'audio.new':
          final target = device;
          if (target is! NecklaceAudioControlPort) {
            return jsonEncode({
              'success': false,
              'error': 'Audio recording control unavailable'
            });
          }
          final operation = action == 'audio.stop'
              ? 0
              : action == 'audio.start'
                  ? 1
                  : 2;
          final accepted = await (target as NecklaceAudioControlPort)
              .writeBackgroundAudio(operation, fileId: fileId);
          return jsonEncode({
            'success': accepted,
            'status': accepted ? 'accepted' : 'failed'
          });
        case 'take_photo':
          final success = await device.writeCamera(Uint8List.fromList(
              [...CameraCommand.capture.toBytes(), ...?fileId]));
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
