import 'dart:io';
import 'dart:typed_data';

import 'opus_pcm_stream_decoder.dart';
import 'wav_audio_player.dart';

/// Decode a finalized necklace NXOPUS v1 recording on the client.
/// Only one compressed frame and its PCM samples are held in memory at a time.
Future<void> decodeNecklaceRecording(File source, File destination,
    {Future<Uint8List> Function(Uint8List)? decodeFrame}) async {
  final decoder = NxOpusPcmStreamDecoder();
  final decode = decodeFrame ?? decoder.decode;
  final input = await source.open();
  RandomAccessFile? output;
  var complete = false;
  try {
    final header = await input.read(12);
    const expected = [78, 88, 79, 80, 85, 83, 1, 0, 128, 62, 120, 0];
    if (header.length != 12 ||
        List.generate(12, (i) => header[i] == expected[i]).contains(false)) {
      throw const FormatException('Unsupported necklace recording format');
    }
    output = await destination.open(mode: FileMode.write);
    await output.writeFrom(Uint8List(44));
    var sequence = 0;
    var pcmBytes = 0;
    while (true) {
      final record = await input.read(6);
      if (record.length != 6) {
        throw const FormatException('Missing recording end marker');
      }
      final fields = ByteData.sublistView(record);
      final index = fields.getUint32(0, Endian.little);
      final size = fields.getUint16(4, Endian.little);
      if (index == 0xffffffff && size == 0) {
        if ((await input.read(1)).isNotEmpty) {
          throw const FormatException('Data after recording end marker');
        }
        break;
      }
      if (index != sequence++ || size == 0 || size > 4096) {
        throw const FormatException('Invalid recording frame');
      }
      final frame = await input.read(size);
      if (frame.length != size) {
        throw const FormatException('Truncated recording frame');
      }
      final pcm = await decode(frame);
      pcmBytes += pcm.length;
      if (pcmBytes > 0xffffffff - 36 || pcm.length.isOdd) {
        throw const FormatException('Invalid PCM size');
      }
      await output.writeFrom(pcm);
    }
    final wav = NxWavAudioPlayer.pcmToWav(Uint8List(0));
    final fields = ByteData.sublistView(wav);
    fields.setUint32(4, 36 + pcmBytes, Endian.little);
    fields.setUint32(40, pcmBytes, Endian.little);
    await output.setPosition(0);
    await output.writeFrom(wav);
    complete = true;
  } finally {
    decoder.dispose();
    await input.close();
    await output?.close();
    if (!complete && output != null && await destination.exists()) {
      await destination.delete();
    }
  }
}
