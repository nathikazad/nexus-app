import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/data/hardware/paired_device_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('get / set / clear paired remote id', () async {
    expect(await PairedDeviceStorage.getPairedRemoteId(), isNull);

    await PairedDeviceStorage.setPairedRemoteId('device-123');
    expect(await PairedDeviceStorage.getPairedRemoteId(), 'device-123');

    final dev = await PairedDeviceStorage.getPairedDevice();
    expect(dev?.remoteId, 'device-123');

    await PairedDeviceStorage.clearPairedRemoteId();
    expect(await PairedDeviceStorage.getPairedRemoteId(), isNull);
    expect(await PairedDeviceStorage.getPairedDevice(), isNull);
  });
}
