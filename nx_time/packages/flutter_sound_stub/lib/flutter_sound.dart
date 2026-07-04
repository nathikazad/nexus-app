import 'dart:typed_data';

enum Codec {
  pcm16,
}

class FlutterSoundPlayer {
  FlutterSoundPlayer({Object? logLevel});

  Future<void> openPlayer() async {}

  Future<void> closePlayer() async {}

  Future<void> stopPlayer() async {}

  Future<void> startPlayerFromStream({
    Codec codec = Codec.pcm16,
    bool interleaved = true,
    int numChannels = 1,
    int sampleRate = 16000,
    int bufferSize = 8192,
    void Function()? onBufferUnderflow,
  }) async {}

  Future<int> feedUint8FromStream(Uint8List buffer) async => buffer.length;
}
