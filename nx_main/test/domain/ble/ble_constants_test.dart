import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/domain/ble/ble_constants.dart';

void main() {
  test('service UUID is non-empty and hyphenated', () {
    expect(BleConstants.serviceUuid.isNotEmpty, isTrue);
    expect(BleConstants.serviceUuid.contains('-'), isTrue);
  });
}
