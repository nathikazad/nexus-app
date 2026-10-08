import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_voice/src/voice/pcm_gain.dart';

void main() {
  test('150 percent amplifies and saturates both polarities without wrapping',
      () {
    final input = ByteData(8);
    for (final (i, value) in [1000, -1000, 30000, -30000].indexed) {
      input.setInt16(i * 2, value, Endian.little);
    }
    final pcm = input.buffer.asUint8List();
    expect(amplifyPcm16(pcm, 1), pcm);
    final output = ByteData.sublistView(amplifyPcm16(pcm, 1.5));
    expect(List.generate(4, (i) => output.getInt16(i * 2, Endian.little)),
        [1500, -1500, 32767, -32768]);
    expect(input.getInt16(0, Endian.little), 1000);
  });
}
