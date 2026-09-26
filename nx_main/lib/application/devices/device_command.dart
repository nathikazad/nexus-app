/// These names are the existing isolate wire contract; do not rename casually.
enum DeviceCommandKind {
  writeHaptic,
  writeCamera,
  readBattery,
  readCameraStatus,
  readRTC,
  writeRTC,
  readDeviceName,
  writeDeviceName,
  writeFileRx,
  readFileCtrl,
  writeFileCtrl,
}

/// A request inside the app. Map serialization belongs to the isolate adapter.
class DeviceCommand {
  DeviceCommand(this.kind, {List<int>? bytes, this.effectId, this.name})
      : bytes = bytes == null ? null : List<int>.unmodifiable(bytes);
  final DeviceCommandKind kind;
  final List<int>? bytes;
  final int? effectId;
  final String? name;
}
