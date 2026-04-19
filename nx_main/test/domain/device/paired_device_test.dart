import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/domain/device/paired_device.dart';

void main() {
  test('PairedDevice stores remoteId', () {
    const d = PairedDevice(remoteId: 'abc-123');
    expect(d.remoteId, 'abc-123');
  });
}
