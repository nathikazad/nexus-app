import 'dart:typed_data';
import '../ble/bg_ble_client.dart';

/// Hardware operations needed by necklace tools and audio delivery.
/// The adapter deliberately delegates to the established BLE implementation.
abstract interface class NecklaceDevicePort {
  Future<void> sendAudio(Uint8List bytes);
  Future<bool> writeCamera(Uint8List bytes);
  Future<(bool, int)?> readCameraStatus();
  Future<Uint8List?> readBattery();
  Future<bool> writeHaptic(int effectId);
}

class BleNecklaceDevicePort implements NecklaceDevicePort {
  BleNecklaceDevicePort(this.client);
  final BleClient client;
  @override
  Future<void> sendAudio(Uint8List bytes) => client.sendAudio(bytes);
  @override
  Future<bool> writeCamera(Uint8List bytes) => client.writeCamera(bytes);
  @override
  Future<(bool, int)?> readCameraStatus() => client.readCameraStatus();
  @override
  Future<Uint8List?> readBattery() => client.readBattery();
  @override
  Future<bool> writeHaptic(int effectId) => client.writeHaptic(effectId);
}
