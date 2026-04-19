import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/data/background/background_service.dart';
import 'package:nexus_voice_assistant/domain/ble/ble_connection_state.dart';

void main() {
  test('BleBackgroundService starts with idle BLE status', () {
    final bg = BleBackgroundService();
    expect(bg.lastKnownBleStatus, BleConnectionState.idle);
  });
}
