import 'package:flutter/services.dart';
import 'package:nx_live_agent/nx_live_agent.dart';

/// Dart adapter for the small AVAudioEngine queue hosted by the macOS runner.
final class MacLiveAudioPlayer implements LiveRealtimeAudioDevice {
  MacLiveAudioPlayer({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName) {
    _channel.setMethodCallHandler(_handleNativeEvent);
  }

  static const _channelName = 'nx_notes/live_agent_pcm_player';
  final MethodChannel _channel;

  void Function()? _onPlaybackStarted;
  void Function()? _onPlaybackStopped;
  void Function(Uint8List bytes)? _onInputPcm16;

  @override
  set onPlaybackStarted(void Function()? callback) =>
      _onPlaybackStarted = callback;

  @override
  set onPlaybackStopped(void Function()? callback) =>
      _onPlaybackStopped = callback;

  Future<void> _handleNativeEvent(MethodCall call) async {
    switch (call.method) {
      case 'playbackStarted':
        _onPlaybackStarted?.call();
      case 'playbackStopped':
        _onPlaybackStopped?.call();
      case 'microphonePcm':
        if (call.arguments case final Uint8List bytes) {
          _onInputPcm16?.call(bytes);
        }
    }
  }

  @override
  Future<void> addPcm16(Uint8List bytes) =>
      _channel.invokeMethod<void>('append', bytes);

  @override
  Future<void> finishResponse() =>
      _channel.invokeMethod<void>('finishResponse');

  @override
  Future<void> pause() => _channel.invokeMethod<void>('pause');

  @override
  Future<void> resume() => _channel.invokeMethod<void>('resume');

  @override
  Future<void> stop() => _channel.invokeMethod<void>('stop');

  @override
  set onInputPcm16(void Function(Uint8List bytes)? callback) =>
      _onInputPcm16 = callback;

  @override
  Future<void> startInput() => _channel.invokeMethod<void>('startMicrophone');

  @override
  Future<void> setInputMuted(bool muted) =>
      _channel.invokeMethod<void>('setMicrophoneMuted', muted);

  @override
  Future<void> stopInput() => _channel.invokeMethod<void>('stopMicrophone');

  @override
  Future<void> dispose() async {
    await stop();
    _channel.setMethodCallHandler(null);
  }
}
