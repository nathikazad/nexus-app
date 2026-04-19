import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/data/battery/battery_repository.dart';
import 'package:nexus_voice_assistant/domain/battery/battery_repository.dart' as domain;

void main() {
  test('HttpBatteryRepository implements domain BatteryRepository', () {
    expect(HttpBatteryRepository(), isA<domain.BatteryRepository>());
  });
}
