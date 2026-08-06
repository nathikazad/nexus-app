import 'dart:io';
import 'dart:typed_data';

Future<String?> writeStoredAudioFile(Uint8List audio) async {
  final filename =
      'nx_stored_audio_${DateTime.now().microsecondsSinceEpoch}.wav';
  final file = File('${Directory.systemTemp.path}/$filename');
  await file.writeAsBytes(audio, flush: false);
  return file.path;
}

Future<void> deleteStoredAudioFile(String? path) async {
  if (path == null) return;
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}
