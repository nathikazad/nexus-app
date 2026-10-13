import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/data/ble/bg_ble_client.dart';
import 'package:nexus_voice_assistant/data/necklace/necklace_device_port.dart';
import 'package:nexus_voice_assistant/data/necklace/necklace_command_handler.dart';

class VolumeClient extends BleClient {
  List<int> volumes = [2, 40, 70, 0, 3, 1, 0];
  bool reject = false;
  int writes = 0;
  @override
  Future<Uint8List?> readVolume() async => Uint8List.fromList(volumes);
  @override
  Future<bool> writeVolume(int output, int percent) async {
    writes++;
    if (reject) return false;
    volumes[output + 1] = percent;
    volumes[3] = 1;
    return true;
  }
}

void main() {
  test('agent preserves independent volumes and reports pending persistence',
      () async {
    final client = VolumeClient();
    final handler = NecklaceCommandHandler(BleNecklaceDevicePort(client));
    var value = jsonDecode((await handler
        .handle(1, 'set_volume', {'output': 'headset', 'percent': 0}))!);
    expect(value, {
      'success': true,
      'connected': 'both',
      'audio_ready': 'left',
      'identifying_buds': 0,
      'speaker': 40,
      'headset': 0,
      'persistence': 'pending'
    });
    client.volumes[3] = 0;
    value = jsonDecode((await handler.handle(2, 'get_volume', {}))!);
    expect(value['persistence'], 'saved');
    await handler
        .handle(3, 'set_volume', {'output': 'speaker', 'percent': 100});
    expect(client.volumes.sublist(1, 3), [100, 0]);
  });
  test('invalid requests never reach BLE and failed writes are visible',
      () async {
    final client = VolumeClient();
    final handler = NecklaceCommandHandler(BleNecklaceDevicePort(client));
    for (final params in [
      {'output': 'both', 'percent': 30},
      {'output': 'speaker', 'percent': 101},
      {'output': 'headset', 'percent': 2.5}
    ]) {
      expect(
          jsonDecode(
              (await handler.handle(1, 'set_volume', params))!)['success'],
          false);
    }
    expect(client.writes, 0);
    client.reject = true;
    expect(
        jsonDecode((await handler.handle(2, 'set_volume',
            {'output': 'speaker', 'percent': 30}))!)['success'],
        false);
  });
}
