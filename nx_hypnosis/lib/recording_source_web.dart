import 'dart:typed_data';

Future<String> recordingSource(Uint8List bytes) async =>
    Uri.dataFromBytes(bytes, mimeType: 'audio/mpeg').toString();

Future<void> releaseRecordingSource(String source) async {}
