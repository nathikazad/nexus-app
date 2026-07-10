import 'dart:async';
import 'dart:typed_data';

import 'package:opus_dart/opus_dart.dart';

import 'opus_codec.dart';

typedef NxPcmOpusEncodeFn = Future<List<Uint8List>> Function(
  Uint8List pcmData, {
  int sampleRate,
  int channels,
  FrameTime frameTime,
  bool fillUpLastFrame,
});

/// Buffers PCM16 input into Opus frame-sized chunks and encodes complete frames.
class NxPcmOpusStreamEncoder {
  NxPcmOpusStreamEncoder({
    this.sampleRate = 16000,
    this.channels = 1,
    this.frameTime = FrameTime.ms60,
    NxPcmOpusEncodeFn? encodePcm16,
  }) : _encodePcm16 = encodePcm16 ?? NxOpusCodec.encodePcm16;

  final int sampleRate;
  final int channels;
  final FrameTime frameTime;
  final NxPcmOpusEncodeFn _encodePcm16;

  final List<Uint8List> _pendingPcm = [];

  void reset() {
    _pendingPcm.clear();
  }

  Future<List<Uint8List>> addPcmChunk(Uint8List chunk) async {
    if (chunk.isEmpty) return const [];
    _pendingPcm.add(chunk);
    final combined = _drainPending();
    final frameSize = frameSizeBytes;
    if (combined.length < frameSize) {
      _pendingPcm.add(combined);
      return const [];
    }

    final completeLength = combined.length - (combined.length % frameSize);
    final complete = Uint8List.sublistView(combined, 0, completeLength);
    if (completeLength < combined.length) {
      _pendingPcm.add(Uint8List.sublistView(combined, completeLength));
    }

    return _encodePcm16(
      complete,
      sampleRate: sampleRate,
      channels: channels,
      frameTime: frameTime,
      fillUpLastFrame: false,
    );
  }

  Future<List<Uint8List>> flush({bool padFinalFrame = true}) async {
    if (_pendingPcm.isEmpty) return const [];
    final remainder = _drainPending();
    return _encodePcm16(
      remainder,
      sampleRate: sampleRate,
      channels: channels,
      frameTime: frameTime,
      fillUpLastFrame: padFinalFrame,
    );
  }

  int get frameSizeBytes {
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

  Uint8List _drainPending() {
    final total = _pendingPcm.fold<int>(0, (sum, chunk) => sum + chunk.length);
    final combined = Uint8List(total);
    var offset = 0;
    for (final chunk in _pendingPcm) {
      combined.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    _pendingPcm.clear();
    return combined;
  }
}
