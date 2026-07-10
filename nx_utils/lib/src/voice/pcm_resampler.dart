import 'dart:math' as math;
import 'dart:typed_data';

/// Stateful mono PCM16 resampler for small real-time chunks.
///
/// Input and output are little-endian signed 16-bit PCM. The implementation is
/// intentionally dependency-free and uses linear interpolation, matching the
/// historical Flutter-side watch resampler.
class NxPcm16MonoResampler {
  NxPcm16MonoResampler({
    required this.inputSampleRate,
    required this.outputSampleRate,
  })  : assert(inputSampleRate > 0),
        assert(outputSampleRate > 0);

  final int inputSampleRate;
  final int outputSampleRate;

  final List<int> _pendingSamples = <int>[];
  int _bufferStartSampleIndex = 0;
  int _inputSamplesSeen = 0;
  int _outputSamplesEmitted = 0;

  double get _inputSamplesPerOutputSample => inputSampleRate / outputSampleRate;

  void reset() {
    _pendingSamples.clear();
    _bufferStartSampleIndex = 0;
    _inputSamplesSeen = 0;
    _outputSamplesEmitted = 0;
  }

  Uint8List process(Uint8List pcm) {
    if (pcm.isEmpty) return Uint8List(0);
    if (pcm.length.isOdd) {
      throw ArgumentError('PCM16 byte length must be even');
    }

    _appendSamples(pcm);
    final output = _drain(allowFinalClamp: false);
    _trimPending();
    return output;
  }

  Uint8List flush() {
    if (_inputSamplesSeen == 0) return Uint8List(0);
    final output = _drain(allowFinalClamp: true);
    reset();
    return output;
  }

  static Uint8List convert(
    Uint8List pcm, {
    required int inputSampleRate,
    required int outputSampleRate,
  }) {
    final resampler = NxPcm16MonoResampler(
      inputSampleRate: inputSampleRate,
      outputSampleRate: outputSampleRate,
    );
    final processed = resampler.process(pcm);
    final flushed = resampler.flush();
    return _concat([processed, flushed]);
  }

  void _appendSamples(Uint8List pcm) {
    final data = ByteData.sublistView(pcm);
    for (var offset = 0; offset < pcm.length; offset += 2) {
      _pendingSamples.add(data.getInt16(offset, Endian.little));
      _inputSamplesSeen++;
    }
  }

  Uint8List _drain({required bool allowFinalClamp}) {
    final targetOutputSamples = allowFinalClamp
        ? (_inputSamplesSeen * outputSampleRate / inputSampleRate).round()
        : null;
    final samples = <int>[];

    while (true) {
      if (targetOutputSamples != null &&
          _outputSamplesEmitted >= targetOutputSamples) {
        break;
      }

      final inputPosition =
          _outputSamplesEmitted * _inputSamplesPerOutputSample;
      final inputFloor = inputPosition.floor();
      if (inputFloor >= _inputSamplesSeen) break;

      final localFloor = inputFloor - _bufferStartSampleIndex;
      if (localFloor < 0 || localFloor >= _pendingSamples.length) break;

      final fraction = inputPosition - inputFloor;
      final needsNextSample = fraction != 0.0;
      final inputCeil = needsNextSample ? inputFloor + 1 : inputFloor;

      if (inputCeil >= _inputSamplesSeen) {
        if (!allowFinalClamp) break;
      }

      final localCeil = math.min(
        math.max(0, inputCeil - _bufferStartSampleIndex),
        _pendingSamples.length - 1,
      );
      final sample1 = _pendingSamples[localFloor];
      final sample2 = _pendingSamples[localCeil];
      final value = sample1 + (sample2 - sample1) * fraction;
      samples.add(value.round().clamp(-32768, 32767));
      _outputSamplesEmitted++;
    }

    return _samplesToPcm(samples);
  }

  void _trimPending() {
    if (_pendingSamples.isEmpty) return;
    final nextInputPosition =
        _outputSamplesEmitted * _inputSamplesPerOutputSample;
    final keepFromGlobal = nextInputPosition.floor();
    final removable = keepFromGlobal - _bufferStartSampleIndex;
    if (removable <= 0) return;

    final clamped = math.min(removable, _pendingSamples.length);
    _pendingSamples.removeRange(0, clamped);
    _bufferStartSampleIndex += clamped;
  }

  static Uint8List _samplesToPcm(List<int> samples) {
    if (samples.isEmpty) return Uint8List(0);
    final bytes = Uint8List(samples.length * 2);
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < samples.length; i++) {
      data.setInt16(i * 2, samples[i], Endian.little);
    }
    return bytes;
  }

  static Uint8List _concat(List<Uint8List> chunks) {
    final total = chunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
    if (total == 0) return Uint8List(0);
    final out = Uint8List(total);
    var offset = 0;
    for (final chunk in chunks) {
      out.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return out;
  }
}
