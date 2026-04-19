/// Auto photo-record status from device (GATT read / device.push).
class CameraRecordStatus {
  final bool isRecording;
  final int periodSec;

  CameraRecordStatus({
    required this.isRecording,
    required this.periodSec,
  });
}
