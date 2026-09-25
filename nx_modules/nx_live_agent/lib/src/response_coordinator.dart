import 'dart:async';

/// Coalesces manual requests while a server or client response is in flight.
/// Audio playback may outlive generation, so both must finish before sending.
final class ResponseCoordinator {
  ResponseCoordinator(this.send);
  final Future<void> Function() send;
  bool _generating = false;
  bool _playing = false;
  bool _pending = false;
  bool _closed = false;

  Future<void> request() async {
    if (_closed) return;
    _pending = true;
    await flush();
  }

  Future<void> flush() async {
    if (_closed || !_pending || _generating || _playing) return;
    _pending = false;
    // Reserve before awaiting the data channel, not after response.created.
    _generating = true;
    try {
      await send();
    } catch (_) {
      _generating = false;
      rethrow;
    }
  }

  void generationStarted() => _generating = true;
  void generationFinished() => _generating = false;
  void playbackStarted() => _playing = true;
  void playbackFinished() => _playing = false;

  void conflict() {
    // Server VAD can win the race before its response.created reaches us.
    // Retain the request and retry only after that response finishes.
    _generating = true;
    _pending = true;
  }

  void close() {
    _closed = true;
    _pending = false;
  }
}
