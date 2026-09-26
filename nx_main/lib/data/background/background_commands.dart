import '../../application/devices/device_command.dart';
import '../../application/devices/device_command_result.dart';

/// The only map adapter for correlated BLE requests and replies.
class BackgroundCommands {
  static Map<String, dynamic> encode(DeviceCommand command, int requestId) => {
        'command': command.kind.name,
        'requestId': requestId,
        if (command.bytes != null ||
            command.effectId != null ||
            command.name != null)
          'data': {
            if (command.bytes != null) 'data': command.bytes!.toList(),
            if (command.effectId != null) 'effectId': command.effectId,
            if (command.name != null) 'name': command.name,
          },
      };

  static (int, DeviceCommand) decode(Map<String, dynamic> event) {
    final kind = DeviceCommandKind.values.byName(event['command'] as String);
    final id = event['requestId'] as int;
    final data = event['data'] as Map?;
    return (
      id,
      DeviceCommand(kind,
          bytes: data?['data'] == null
              ? null
              : List<int>.from(data!['data'] as List),
          effectId: data?['effectId'] as int?,
          name: data?['name'] as String?)
    );
  }

  static Map<String, dynamic> encodeResult(DeviceCommandResult result) => {
        'command': result.kind.name,
        'requestId': result.requestId,
        'success': result.success,
        if (result.bytes != null) 'data': result.bytes,
        if (result.text != null) 'data': result.text,
        if (result.error != null) 'error': result.error,
      };

  static DeviceCommandResult decodeResult(Map<String, dynamic> event) =>
      DeviceCommandResult(
          kind: DeviceCommandKind.values.byName(event['command'] as String),
          requestId: event['requestId'] as int,
          success: event['success'] == true,
          bytes: event['data'] is List ? List<int>.from(event['data']) : null,
          text: event['data'] is String ? event['data'] as String : null,
          error: event['error'] as String?);
}
