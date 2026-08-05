import 'dart:async';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart';

class NxStoredAudioPlayer {
  final FlutterSoundPlayer _player = FlutterSoundPlayer(logLevel: Level.off);
  StreamSubscription<PlaybackDisposition>? _progressSubscription;
  bool _open = false;
  bool _sourceStarted = false;
  bool _playing = false;

  void Function(Duration position, Duration duration)? onProgress;
  void Function(bool playing)? onPlaybackStateChanged;
  VoidCallback? onComplete;

  bool get isPlaying => _playing;

  Future<void> play(String url, {Duration? startAt}) async {
    await _ensureOpen();
    if (!_sourceStarted) {
      await _player.startPlayer(
        fromURI: url,
        codec: Codec.pcm16WAV,
        whenFinished: () {
          _sourceStarted = false;
          _markPlaying(false);
          onComplete?.call();
        },
      );
      _sourceStarted = true;
      if (startAt != null && startAt > Duration.zero) {
        await _player.seekToPlayer(startAt);
      }
    } else {
      await _player.resumePlayer();
    }
    _markPlaying(true);
  }

  Future<void> pause() async {
    if (!_sourceStarted || !_playing) return;
    await _player.pausePlayer();
    _markPlaying(false);
  }

  Future<void> seek(Duration position) async {
    if (!_sourceStarted) return;
    await _player.seekToPlayer(position);
  }

  Future<void> stop() async {
    if (_sourceStarted || _open) {
      await _player.stopPlayer();
    }
    _sourceStarted = false;
    _markPlaying(false);
  }

  Future<void> dispose() async {
    await _progressSubscription?.cancel();
    _progressSubscription = null;
    await stop();
    if (_open) {
      await _player.closePlayer();
      _open = false;
    }
  }

  Future<void> _ensureOpen() async {
    if (_open) return;
    await _player.openPlayer();
    await _player.setSubscriptionDuration(const Duration(milliseconds: 120));
    _progressSubscription = _player.onProgress?.listen((event) {
      onProgress?.call(event.position, event.duration);
    });
    _open = true;
  }

  void _markPlaying(bool value) {
    if (_playing == value) return;
    _playing = value;
    onPlaybackStateChanged?.call(value);
  }
}

typedef VoidCallback = void Function();
