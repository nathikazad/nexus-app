import 'device_command.dart';

class DeviceCommandResult {
  const DeviceCommandResult(
      {required this.kind,
      required this.requestId,
      required this.success,
      this.bytes,
      this.text,
      this.error});
  final DeviceCommandKind kind;
  final int requestId;
  final bool success;
  final List<int>? bytes;
  final String? text;
  final String? error;
}
