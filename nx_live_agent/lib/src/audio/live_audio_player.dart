import 'dart:typed_data';

/// Plays streamed PCM output while retaining queued audio across pause/resume.
abstract interface class LiveAudioPlayer {
  set onPlaybackStarted(void Function()? callback);
  set onPlaybackStopped(void Function()? callback);

  Future<void> addPcm16(Uint8List bytes);
  Future<void> finishResponse();
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> dispose();
}

/// Full-duplex audio device used by transports that exchange raw PCM.
abstract interface class LiveRealtimeAudioDevice implements LiveAudioPlayer {
  set onInputPcm16(void Function(Uint8List bytes)? callback);

  Future<void> startInput();
  Future<void> setInputMuted(bool muted);
  Future<void> stopInput();
}
