import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/data/file_transfer/relay.dart';
import 'package:nexus_voice_assistant/data/file_transfer/protocol.dart';

void main() {
  final m =
      FileManifest('12' * 16, FileKind.photo, 'photo.jpg', 3, crc32([1, 2, 3]));
  test('relays bytes unchanged; only server can acknowledge', () async {
    final up = <Uint8List>[], down = <Uint8List>[];
    final relay = FileRelay(sendToServer: (b) {
      up.add(b);
      return true;
    }, sendToDevice: (b) async {
      down.add(b);
    });
    expect(relay.fromDevice(m.open()), true);
    expect(up.single, m.open());
    expect(down, isEmpty);
    await relay.fromServer(m.status(1, 0));
    await relay.fromServer(m.status(1, 3, committed: true));
    expect(down.last, m.status(1, 3, committed: true));
    expect(() => relay.fromDevice(m.status(1, 3, committed: true)),
        throwsFormatException);
    await relay.close();
    expect(relay.fromDevice(m.open()), false);
  });
  test('offline packets are not queued or acknowledged', () async {
    var online = false;
    var sent = 0;
    final relay = FileRelay(sendToServer: (b) {
      if (online) sent++;
      return online;
    }, sendToDevice: (b) async {
      fail('Synthetic ack');
    });
    for (var i = 0; i < 100; i++) {
      expect(relay.fromDevice(m.open()), false);
    }
    online = true;
    expect(sent, 0);
    expect(relay.fromDevice(m.open()), true);
    expect(sent, 1);
  });
}
