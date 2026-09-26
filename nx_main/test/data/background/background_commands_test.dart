import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/application/devices/device_command.dart';
import 'package:nexus_voice_assistant/application/devices/device_command_result.dart';
import 'package:nexus_voice_assistant/data/background/background_commands.dart';

void main() {
  test('camera request preserves existing isolate shape and owns its bytes',
      () {
    final source = [4, 60, 0];
    final command = DeviceCommand(DeviceCommandKind.writeCamera, bytes: source);
    source[0] = 99;
    final wire = BackgroundCommands.encode(command, 12);
    expect(wire, {
      'command': 'writeCamera',
      'requestId': 12,
      'data': {
        'data': [4, 60, 0]
      }
    });
    final (id, decoded) = BackgroundCommands.decode(wire);
    expect(id, 12);
    expect(decoded.kind, DeviceCommandKind.writeCamera);
    expect(decoded.bytes, [4, 60, 0]);
  });
  test('all command names roundtrip and replies retain correlation', () {
    for (final kind in DeviceCommandKind.values) {
      final (id, command) = BackgroundCommands.decode(
          BackgroundCommands.encode(DeviceCommand(kind), 8));
      expect(id, 8);
      expect(command.kind, kind);
      final reply = BackgroundCommands.decodeResult(
          BackgroundCommands.encodeResult(DeviceCommandResult(
              kind: kind, requestId: 8, success: false, error: 'unavailable')));
      expect(reply.kind, kind);
      expect(reply.requestId, 8);
      expect(reply.success, false);
      expect(reply.error, 'unavailable');
    }
  });
  test('read replies decode bytes and name without dynamic data in consumers',
      () {
    final bytes = BackgroundCommands.decodeResult({
      'command': 'readBattery',
      'requestId': 1,
      'success': true,
      'data': [1, 2, 3]
    });
    expect(bytes.bytes, [1, 2, 3]);
    expect(bytes.text, isNull);
    final name = BackgroundCommands.decodeResult({
      'command': 'readDeviceName',
      'requestId': 2,
      'success': true,
      'data': 'Nexless'
    });
    expect(name.text, 'Nexless');
    expect(name.bytes, isNull);
  });
  test('unknown or malformed commands fail at the boundary', () {
    expect(
        () => BackgroundCommands.decode({'command': 'bogus', 'requestId': 1}),
        throwsArgumentError);
    expect(
        () => BackgroundCommands.decode({
              'command': 'writeCamera',
              'requestId': 1,
              'data': {
                'data': ['oops']
              }
            }),
        throwsA(isA<TypeError>()));
  });
}
