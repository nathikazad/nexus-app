import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_voice/src/voice/recording_file_decoder.dart';

void main() {
  late Directory dir;
  setUp(() async {
    dir = await Directory(
            '../../../tmp/necklace-playback-oct7')
        .createTemp('decoder-test-');
  });
  tearDown(() async => dir.delete(recursive: true));
  List<int> record(int seq, List<int> data) {
    final header = ByteData(6)
      ..setUint32(0, seq, Endian.little)
      ..setUint16(4, data.length, Endian.little);
    return [...header.buffer.asUint8List(), ...data];
  }

  const header = [78, 88, 79, 80, 85, 83, 1, 0, 128, 62, 120, 0];
  Future<Uint8List> decode(Uint8List data) async =>
      Uint8List.fromList([data[0], 0]);
  test('frames decode in order into a playable PCM WAV', () async {
    final source = File('${dir.path}/audio.opusraw');
    final dest = File('${dir.path}/audio.wav');
    await source.writeAsBytes([
      ...header,
      ...record(0, [7]),
      ...record(1, [8]),
      ...record(0xffffffff, [])
    ]);
    await decodeNecklaceRecording(source, dest, decodeFrame: decode);
    final wav = await dest.readAsBytes();
    expect(String.fromCharCodes(wav.take(4)), 'RIFF');
    expect(ByteData.sublistView(wav).getUint32(24, Endian.little), 16000);
    expect(ByteData.sublistView(wav).getUint32(40, Endian.little), 4);
    expect(wav.sublist(44), [7, 0, 8, 0]);
  });
  test(
      'rejects bad header, missing EOF, sequence gaps, truncation and trailing data',
      () async {
    for (final bytes in <List<int>>[
      [0],
      [
        ...header,
        ...record(0, [1])
      ],
      [
        ...header,
        ...record(1, [1]),
        ...record(0xffffffff, [])
      ],
      [
        ...header,
        ...record(0, [1, 2]).take(7)
      ],
      [...header, ...record(0xffffffff, []), 1],
    ]) {
      final source = File('${dir.path}/bad.opusraw');
      final dest = File('${dir.path}/bad.wav');
      await source.writeAsBytes(bytes);
      await expectLater(
          decodeNecklaceRecording(source, dest, decodeFrame: decode),
          throwsFormatException);
      expect(await dest.exists(), false);
    }
  });
}
