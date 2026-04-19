import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/domain/battery/battery_point.dart';

void main() {
  test('BatteryPoint holds HMS and charging', () {
    const p = BatteryPoint(
      timeHms: '14:30:00',
      percent: 55,
      voltageMv: 3900,
      charging: true,
    );
    expect(p.timeHms, '14:30:00');
    expect(p.charging, isTrue);
  });
}
