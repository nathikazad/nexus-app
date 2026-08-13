import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nx_voice/stored_audio.dart';

void main() {
  test('parses Nexus length-prefixed Opus packets', () {
    final bytes = BytesBuilder()
      ..add(<int>[0x4f, 0x50, 0x55, 0x53])
      ..add(_u32(16000))
      ..add(_u32(1920))
      ..add(_u16(3))
      ..add(<int>[1, 2, 3])
      ..add(_u16(2))
      ..add(<int>[4, 5]);

    final audio = NxStoredOpusAudio.tryParse(bytes.takeBytes());

    expect(audio, isNotNull);
    expect(audio!.sampleRate, 16000);
    expect(audio.frameSizeSamples, 1920);
    expect(audio.frameDuration, const Duration(milliseconds: 120));
    expect(audio.packets, hasLength(2));
    expect(audio.packets[0], <int>[1, 2, 3]);
    expect(audio.packets[1], <int>[4, 5]);
  });

  test('returns null for legacy WAV data', () {
    expect(
      NxStoredOpusAudio.tryParse(Uint8List.fromList('RIFF'.codeUnits)),
      isNull,
    );
  });

  test('rejects a truncated packet', () {
    final bytes = BytesBuilder()
      ..add(<int>[0x4f, 0x50, 0x55, 0x53])
      ..add(_u32(16000))
      ..add(_u32(1920))
      ..add(_u16(4))
      ..add(<int>[1]);

    expect(
      () => NxStoredOpusAudio.tryParse(bytes.takeBytes()),
      throwsFormatException,
    );
  });
}

Uint8List _u16(int value) {
  final data = ByteData(2)..setUint16(0, value, Endian.little);
  return data.buffer.asUint8List();
}

Uint8List _u32(int value) {
  final data = ByteData(4)..setUint32(0, value, Endian.little);
  return data.buffer.asUint8List();
}
