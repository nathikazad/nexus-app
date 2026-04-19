import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/domain/ble/battery_data.dart';

void main() {
  test('BatteryData holds fields', () {
    final b = BatteryData(percentage: 42, voltage: 3.9, isCharging: false);
    expect(b.percentage, 42);
    expect(b.voltage, 3.9);
    expect(b.isCharging, isFalse);
  });
}
