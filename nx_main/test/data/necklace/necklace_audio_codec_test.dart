import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_voice_assistant/data/necklace/necklace_audio_codec.dart';

void main() {
  Uint8List eof() => Uint8List.fromList([0xfc, 0xff, 1, 0, 0, 0]);
  Uint8List audio() =>
      Uint8List.fromList([1, 0, 1, 0, 0, 0, 0, 0, 0x23, 0x87, 2, 0, 9, 8]);
  test('EOF requires audio and uses the first packet meta, once', () {
    final codec = NecklaceAudioCodec();
    final summaries = <Map<String, dynamic>>[];
    codec.onAudioReceptionSummary = summaries.add;
    expect(codec.decode(eof()), isNull);
    expect(codec.decode(audio()), [0x23, 0x87, 2, 0, 9, 8]);
    expect(codec.decode(eof()), [0xfc, 0xff, 0x23, 0x87]);
    expect(codec.decode(eof()), isNull);
    expect(summaries, [
      {
        'opus_packets': 1,
        'opus_bytes': 2,
        'turn_id': 7,
        'nonce': 8,
        'turnkey': '8:7'
      }
    ]);
  });
  test('session reset prevents EOF from reusing retired session metadata', () {
    final codec = NecklaceAudioCodec();
    codec.decode(audio());
    codec.reset();
    expect(codec.decode(eof()), isNull);
  });
  test('decoder honors buffer offset and rejects declared-length mismatch', () {
    final codec = NecklaceAudioCodec();
    final container = Uint8List.fromList([99, ...audio(), 99]);
    expect(
        codec.decode(Uint8List.sublistView(container, 1, container.length - 1)),
        [0x23, 0x87, 2, 0, 9, 8]);
    final bad = audio()..[10] = 3;
    expect(codec.decode(bad), isNull);
  });
}
