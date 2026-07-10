import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_utils/nx_utils.dart';
import 'package:opus_dart/opus_dart.dart';

void main() {
  group('NxPcm16MonoResampler', () {
    test('converts 24 kHz PCM sample count to 16 kHz', () {
      final pcm24 = _pcmRamp(sampleCount: 240);
      final pcm16 = NxPcm16MonoResampler.convert(
        pcm24,
        inputSampleRate: 24000,
        outputSampleRate: 16000,
      );

      expect(pcm16.length, 160 * 2);
    });

    test('converts 16 kHz PCM sample count to 24 kHz', () {
      final pcm16 = _pcmRamp(sampleCount: 160);
      final pcm24 = NxPcm16MonoResampler.convert(
        pcm16,
        inputSampleRate: 16000,
        outputSampleRate: 24000,
      );

      expect(pcm24.length, 240 * 2);
    });

    test('chunked resampling matches whole-buffer resampling', () {
      final pcm24 = _pcmRamp(sampleCount: 1201);
      final whole = NxPcm16MonoResampler.convert(
        pcm24,
        inputSampleRate: 24000,
        outputSampleRate: 16000,
      );

      final streaming = NxPcm16MonoResampler(
        inputSampleRate: 24000,
        outputSampleRate: 16000,
      );
      final chunks = <Uint8List>[
        streaming.process(Uint8List.sublistView(pcm24, 0, 222)),
        streaming.process(Uint8List.sublistView(pcm24, 222, 1098)),
        streaming.process(Uint8List.sublistView(pcm24, 1098)),
        streaming.flush(),
      ];

      expect(_concat(chunks), whole);
    });
  });

  group('NxPcmOpusStreamEncoder', () {
    test('emits complete 60 ms frames and flushes a padded final frame',
        () async {
      final encoder = NxPcmOpusStreamEncoder(encodePcm16: _fakeEncode);
      final frameBytes = encoder.frameSizeBytes;
      expect(frameBytes, 1920);

      final frame = _pcmRamp(sampleCount: frameBytes ~/ 2);
      final first = await encoder.addPcmChunk(
        Uint8List.sublistView(frame, 0, 1000),
      );
      expect(first, isEmpty);

      final second = await encoder.addPcmChunk(
        Uint8List.sublistView(frame, 1000),
      );
      expect(second, hasLength(1));

      final noRemainder = await encoder.flush();
      expect(noRemainder, isEmpty);

      final partial = NxPcmOpusStreamEncoder(encodePcm16: _fakeEncode);
      await partial.addPcmChunk(Uint8List.sublistView(frame, 0, 400));
      final padded = await partial.flush();
      expect(padded, hasLength(1));
    });
  });
}

Uint8List _pcmRamp({required int sampleCount}) {
  final bytes = Uint8List(sampleCount * 2);
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i < sampleCount; i++) {
    data.setInt16(i * 2, ((i * 37) % 30000) - 15000, Endian.little);
  }
  return bytes;
}

Future<List<Uint8List>> _fakeEncode(
  Uint8List pcmData, {
  int sampleRate = 16000,
  int channels = 1,
  FrameTime frameTime = FrameTime.ms60,
  bool fillUpLastFrame = true,
}) async {
  return [
    Uint8List.fromList([pcmData.length & 0xFF])
  ];
}

Uint8List _concat(List<Uint8List> chunks) {
  final total = chunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
  final out = Uint8List(total);
  var offset = 0;
  for (final chunk in chunks) {
    out.setRange(offset, offset + chunk.length, chunk);
    offset += chunk.length;
  }
  return out;
}
