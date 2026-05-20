import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:opus_dart/opus_dart.dart';
import 'package:opus_flutter/opus_flutter.dart' as opus_flutter;

class NxOpusCodec {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized || kIsWeb) {
      _initialized = true;
      return;
    }
    initOpus(await opus_flutter.load());
    _initialized = true;
  }

  static Future<List<Uint8List>> encodePcm16(
    Uint8List pcmData, {
    int sampleRate = 16000,
    int channels = 1,
    FrameTime frameTime = FrameTime.ms20,
    bool fillUpLastFrame = true,
  }) async {
    await initialize();
    final frameSizeBytes = _frameSizeBytes(
      sampleRate: sampleRate,
      channels: channels,
      frameTime: frameTime,
    );
    final working =
        fillUpLastFrame ? _paddedToFrameSize(pcmData, frameSizeBytes) : pcmData;
    if (!fillUpLastFrame && working.length % frameSizeBytes != 0) {
      throw ArgumentError(
        'PCM length ${working.length} is not a multiple of frame size '
        '$frameSizeBytes',
      );
    }

    final encoder = SimpleOpusEncoder(
      sampleRate: sampleRate,
      channels: channels,
      application: Application.audio,
    );
    try {
      final packets = <Uint8List>[];
      for (var offset = 0; offset < working.length; offset += frameSizeBytes) {
        final frame = Uint8List.sublistView(
          working,
          offset,
          offset + frameSizeBytes,
        );
        packets.add(encoder.encode(input: _pcmBytesToInt16(frame)));
      }
      return packets;
    } finally {
      encoder.destroy();
    }
  }

  static Future<Uint8List> decodeToPcm16(
    Iterable<Uint8List> opusPackets, {
    int sampleRate = 16000,
    int channels = 1,
  }) async {
    await initialize();
    final decoder = StreamOpusDecoder.bytes(
      floatOutput: false,
      sampleRate: sampleRate,
      channels: channels,
      copyOutput: true,
      forwardErrorCorrection: false,
    );

    final decoded = <Uint8List>[];
    await for (final chunk in decoder.bind(Stream.fromIterable(opusPackets))) {
      decoded.add(
        chunk is Uint8List
            ? chunk
            : Uint8List.fromList(chunk.map((value) => value.toInt()).toList()),
      );
    }

    final totalLength =
        decoded.fold<int>(0, (sum, chunk) => sum + chunk.length);
    final result = Uint8List(totalLength);
    var offset = 0;
    for (final chunk in decoded) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return result;
  }

  static int _frameSizeBytes({
    required int sampleRate,
    required int channels,
    required FrameTime frameTime,
  }) {
    final millis = switch (frameTime) {
      FrameTime.ms2_5 => 2.5,
      FrameTime.ms5 => 5.0,
      FrameTime.ms10 => 10.0,
      FrameTime.ms20 => 20.0,
      FrameTime.ms40 => 40.0,
      FrameTime.ms60 => 60.0,
    };
    return (sampleRate * (millis / 1000) * channels * 2).round();
  }

  static Uint8List _paddedToFrameSize(Uint8List pcmData, int frameSizeBytes) {
    final remainder = pcmData.length % frameSizeBytes;
    if (remainder == 0) return pcmData;
    final padded = Uint8List(pcmData.length + frameSizeBytes - remainder);
    padded.setRange(0, pcmData.length, pcmData);
    return padded;
  }

  static Int16List _pcmBytesToInt16(Uint8List pcm) {
    if (pcm.lengthInBytes % 2 != 0) {
      throw ArgumentError('PCM16 byte length must be even');
    }
    final samples = Int16List(pcm.lengthInBytes ~/ 2);
    final data = ByteData.sublistView(pcm);
    for (var i = 0; i < samples.length; i++) {
      samples[i] = data.getInt16(i * 2, Endian.little);
    }
    return samples;
  }
}
