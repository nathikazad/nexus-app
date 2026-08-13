import 'dart:typed_data';

class NxStoredOpusAudio {
  const NxStoredOpusAudio({
    required this.sampleRate,
    required this.frameSizeSamples,
    required this.packets,
  });

  final int sampleRate;
  final int frameSizeSamples;
  final List<Uint8List> packets;

  Duration get frameDuration => Duration(
        microseconds:
            (frameSizeSamples * Duration.microsecondsPerSecond) ~/ sampleRate,
      );

  static NxStoredOpusAudio? tryParse(Uint8List bytes) {
    if (bytes.length < 12 ||
        bytes[0] != 0x4f ||
        bytes[1] != 0x50 ||
        bytes[2] != 0x55 ||
        bytes[3] != 0x53) {
      return null;
    }
    final data = ByteData.sublistView(bytes);
    final sampleRate = data.getUint32(4, Endian.little);
    final frameSizeSamples = data.getUint32(8, Endian.little);
    if (sampleRate <= 0 || frameSizeSamples <= 0) {
      throw const FormatException('Invalid stored Opus audio header.');
    }
    final packets = <Uint8List>[];
    var offset = 12;
    while (offset < bytes.length) {
      if (offset + 2 > bytes.length) {
        throw const FormatException('Truncated stored Opus frame length.');
      }
      final length = data.getUint16(offset, Endian.little);
      offset += 2;
      if (length == 0 || offset + length > bytes.length) {
        throw const FormatException('Truncated stored Opus frame.');
      }
      packets.add(Uint8List.sublistView(bytes, offset, offset + length));
      offset += length;
    }
    if (packets.isEmpty) {
      throw const FormatException('Stored Opus audio has no frames.');
    }
    return NxStoredOpusAudio(
      sampleRate: sampleRate,
      frameSizeSamples: frameSizeSamples,
      packets: packets,
    );
  }
}
