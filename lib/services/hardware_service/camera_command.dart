import 'dart:typed_data';

/// Camera command sent to the camera BLE characteristic.
enum CameraCommand {
  /// Trigger a single photo capture.
  capture(1),

  /// Start recording.
  startRecord(2),

  /// Stop recording.
  stopRecord(3),

  /// Set record period in seconds.
  /// Requires [period] parameter (1-1000).
  setRecordPeriod(4);

  const CameraCommand(this.value);
  final int value;

  /// Encode the command to bytes for BLE write.
  /// For [setRecordPeriod], [period] must be 1-1000.
  Uint8List toBytes({int? period}) {
    switch (this) {
      case CameraCommand.capture:
      case CameraCommand.startRecord:
      case CameraCommand.stopRecord:
        return Uint8List.fromList([value]);
      case CameraCommand.setRecordPeriod:
        if (period == null || period < 1 || period > 1000) {
          throw ArgumentError('SetRecordPeriod requires period in range 1-1000, got: $period');
        }
        return Uint8List.fromList([
          value,
          period & 0xff,
          (period >> 8) & 0xff,
        ]);
    }
  }
}
