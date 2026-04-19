import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/data/ble/bg_ble_client.dart';

void main() {
  test('BleClient.parseBatteryStatus reads voltage percent charging', () {
    final data = Uint8List.fromList([
      0x10, 0x0E, 80, 1, // 4110 mV, 80%, charging
      0, 0, 12, 15, 4, 26, 0, 0, // minimal clock + tz
    ]);
    final parsed = BleClient.parseBatteryStatus(data);
    expect(parsed, isNotNull);
    expect(parsed!.voltageMv, 4110);
    expect(parsed.percent, 80);
    expect(parsed.charging, isTrue);
  });

  test('BleClient.parseBatteryStatus returns null for short payload', () {
    expect(BleClient.parseBatteryStatus(Uint8List.fromList([1, 2])), isNull);
  });
}
