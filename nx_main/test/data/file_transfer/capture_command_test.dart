import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/data/ble/bg_ble_client.dart';
import 'package:nexus_voice_assistant/data/necklace/necklace_device_port.dart';
import 'package:nexus_voice_assistant/data/necklace/necklace_command_handler.dart';

class CaptureDevice extends BleClient {
  final photos = <Uint8List>[];
  final audio = <(int, Uint8List?)>[];
  @override
  Future<bool> writeCamera(Uint8List data) async {
    photos.add(data);
    return true;
  }

  @override
  Future<bool> writeBackgroundAudio(int operation, {Uint8List? fileId}) async {
    audio.add((operation, fileId));
    return true;
  }
}

void main() {
  test('camera/start/new preserve capture ID; stop needs none', () async {
    final device = CaptureDevice();
    final handler = NecklaceCommandHandler(BleNecklaceDevicePort(device));
    final id = '12' * 16;
    for (final action in ['take_photo', 'audio.start', 'audio.new']) {
      expect(
          jsonDecode(
              (await handler.handle(1, action, {'file_id': id}))!)['success'],
          true);
    }
    await handler.handle(2, 'audio.stop', {});
    expect(device.photos.single, [1, ...List.filled(16, 0x12)]);
    expect(device.audio[0].$1, 1);
    expect(device.audio[1].$1, 2);
    expect(device.audio[0].$2, List.filled(16, 0x12));
    expect(device.audio[1].$2, List.filled(16, 0x12));
    expect(device.audio[2], (0, null));
  });
  test('invalid capture IDs fail before writing hardware', () async {
    final device = CaptureDevice();
    final handler = NecklaceCommandHandler(BleNecklaceDevicePort(device));
    for (final id in ['../file', '0' * 32, '12' * 15, 42]) {
      expect(
          jsonDecode((await handler.handle(1, 'take_photo', {'file_id': id}))!)[
              'success'],
          false);
    }
    expect(device.photos, isEmpty);
    expect(device.audio, isEmpty);
  });
}
