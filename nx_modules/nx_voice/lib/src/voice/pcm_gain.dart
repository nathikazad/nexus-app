import 'dart:typed_data';

/// Amplify PCM16 little-endian samples, saturating rather than wrapping.
Uint8List amplifyPcm16(Uint8List pcm, double gain) {
  if (pcm.length.isOdd || !gain.isFinite || gain < 0 || gain > 1.5) {
    throw ArgumentError('Expected PCM16 and gain between 0 and 1.5');
  }
  final result = Uint8List.fromList(pcm);
  final samples = ByteData.sublistView(result);
  for (var i = 0; i < result.length; i += 2) {
    final value = (samples.getInt16(i, Endian.little) * gain)
        .round()
        .clamp(-32768, 32767);
    samples.setInt16(i, value, Endian.little);
  }
  return result;
}
