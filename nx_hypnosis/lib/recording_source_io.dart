import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<String> recordingSource(Uint8List bytes) async {
  final directory = await getTemporaryDirectory();
  final playback = await directory.createTemp('nx-hypnosis-');
  final file = File('${playback.path}/recording.mp3');
  await file.writeAsBytes(bytes, flush: true);
  return file.uri.toString();
}

Future<void> releaseRecordingSource(String source) async {
  final file = File.fromUri(Uri.parse(source));
  if (await file.exists()) await file.delete();
  if (await file.parent.exists()) await file.parent.delete();
}
