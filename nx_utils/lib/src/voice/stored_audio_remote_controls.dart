import 'dart:async';

import 'package:audio_service/audio_service.dart';

typedef NxRemoteAudioAction = Future<void> Function();
typedef NxRemoteAudioSeek = Future<void> Function(Duration position);

class NxStoredAudioRemoteControls extends BaseAudioHandler with SeekHandler {
  NxStoredAudioRemoteControls._();

  static Future<NxStoredAudioRemoteControls>? _initialization;

  static Future<NxStoredAudioRemoteControls> initialize() {
    return _initialization ??= AudioService.init<NxStoredAudioRemoteControls>(
      builder: NxStoredAudioRemoteControls._,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.nexus.nxNotes.note_audio',
        androidNotificationChannelName: 'Note audio',
        rewindInterval: Duration(seconds: 15),
        fastForwardInterval: Duration(seconds: 15),
      ),
    );
  }

  Object? _owner;
  NxRemoteAudioAction? _onPlay;
  NxRemoteAudioAction? _onPause;
  NxRemoteAudioAction? _onStop;
  NxRemoteAudioSeek? _onSeek;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  double _speed = 1;
  AudioProcessingState _processingState = AudioProcessingState.idle;

  void bind({
    required Object owner,
    required String mediaId,
    required Duration duration,
    required NxRemoteAudioAction onPlay,
    required NxRemoteAudioAction onPause,
    required NxRemoteAudioAction onStop,
    required NxRemoteAudioSeek onSeek,
    required double speed,
  }) {
    _owner = owner;
    _onPlay = onPlay;
    _onPause = onPause;
    _onStop = onStop;
    _onSeek = onSeek;
    _duration = duration;
    _speed = speed;
    _processingState = AudioProcessingState.ready;
    mediaItem.add(
      MediaItem(
        id: mediaId,
        album: 'Nx Notes',
        title: 'Note audio',
        duration: duration,
      ),
    );
    _publish();
  }

  void unbind(Object owner) {
    if (!identical(owner, _owner)) return;
    _owner = null;
    _onPlay = null;
    _onPause = null;
    _onStop = null;
    _onSeek = null;
    _playing = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    _speed = 1;
    _processingState = AudioProcessingState.idle;
    mediaItem.add(null);
    _publish();
  }

  void update({
    Duration? position,
    Duration? duration,
    bool? playing,
    double? speed,
    AudioProcessingState? processingState,
  }) {
    if (position != null) _position = position;
    if (duration != null && duration > Duration.zero) _duration = duration;
    if (playing != null) _playing = playing;
    if (speed != null) _speed = speed;
    if (processingState != null) _processingState = processingState;
    _publish();
  }

  @override
  Future<void> play() async => _onPlay?.call();

  @override
  Future<void> pause() async => _onPause?.call();

  @override
  Future<void> stop() async => _onStop?.call();

  @override
  Future<void> seek(Duration position) async => _onSeek?.call(position);

  void _publish() {
    final bound = _owner != null;
    playbackState.add(
      PlaybackState(
        controls: bound
            ? <MediaControl>[
                MediaControl.rewind,
                _playing ? MediaControl.pause : MediaControl.play,
                MediaControl.fastForward,
              ]
            : const <MediaControl>[],
        systemActions: bound
            ? const <MediaAction>{
                MediaAction.seek,
                MediaAction.seekBackward,
                MediaAction.seekForward,
              }
            : const <MediaAction>{},
        androidCompactActionIndices: bound ? const <int>[0, 1, 2] : null,
        processingState: _processingState,
        playing: _playing,
        updatePosition: _position,
        bufferedPosition: _duration,
        speed: _speed,
      ),
    );
  }
}
