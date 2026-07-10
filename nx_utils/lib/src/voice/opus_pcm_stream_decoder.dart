import 'dart:typed_data';

import 'package:opus_dart/opus_dart.dart';

import 'opus_codec.dart';

/// Streaming Opus decoder that returns PCM16 chunks.
class NxOpusPcmStreamDecoder {
  NxOpusPcmStreamDecoder({
    this.sampleRate = 16000,
    this.channels = 1,
  });

  final int sampleRate;
  final int channels;

  SimpleOpusDecoder? _decoder;

  Future<Uint8List> decode(Uint8List opus) async {
    if (opus.isEmpty) return Uint8List(0);
    await NxOpusCodec.initialize();
    _decoder ??= SimpleOpusDecoder(
      sampleRate: sampleRate,
      channels: channels,
    );
    final samples = _decoder!.decode(input: opus);
    return Uint8List.sublistView(samples);
  }

  void reset() {
    _decoder?.destroy();
    _decoder = null;
  }

  void dispose() {
    reset();
  }
}
