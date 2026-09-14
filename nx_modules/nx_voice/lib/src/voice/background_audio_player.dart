import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'stored_audio_remote_controls.dart';

/// Shared bridge from just_audio to native background playback and media controls.
/// The app owns source selection and UI; this owns the session and control state.
class NxBackgroundAudioPlayer {
  NxBackgroundAudioPlayer({AudioPlayer? player})
      : player = player ?? AudioPlayer() {
    _subscriptions.add(this.player.playbackEventStream.listen((_) => _publish(),
        onError: (Object _, StackTrace __) => _publishError()));
    _subscriptions.add(this.player.playerStateStream.listen((_) => _publish()));
    _subscriptions.add(this.player.positionStream.listen((_) => _publish()));
    _subscriptions.add(this.player.durationStream.listen((_) => _publish()));
    _subscriptions.add(this.player.speedStream.listen((_) => _publish()));
  }
  final AudioPlayer player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  NxStoredAudioRemoteControls? _controls;
  bool _disposed = false;

  static Future<void> initialize(
      {required String channelId, required String channelName}) async {
    await NxStoredAudioRemoteControls.initialize(
        channelId: channelId, channelName: channelName);
  }

  Future<void> prepare(
      {required String id,
      required String title,
      required String album,
      Future<void> Function()? onStop}) async {
    final controls = await NxStoredAudioRemoteControls.initialize();
    final session = await AudioSession.instance;
    // just_audio handles interruptions and unplugged headphones using this
    // shared audio session. Spoken recordings pause rather than duck.
    await session.configure(const AudioSessionConfiguration.speech());
    if (_disposed) return;
    _controls = controls;
    controls.bind(
        owner: this,
        mediaId: id,
        title: title,
        album: album,
        duration: player.duration ?? Duration.zero,
        speed: player.speed,
        onPlay: _resume,
        onPause: player.pause,
        onStop: onStop ?? stop,
        onSeek: player.seek);
    _publish();
  }

  Future<void> _resume() async {
    if (_disposed) return;
    if (player.processingState == ProcessingState.completed)
      await player.seek(Duration.zero);
    unawaited(player.play().catchError((Object _) => _publishError()));
  }

  void _publishError() => _controls?.update(
      owner: this, playing: false, processingState: AudioProcessingState.error);

  void _publish() {
    if (_disposed) return;
    _controls?.update(
        owner: this,
        position: player.position,
        duration: player.duration ?? Duration.zero,
        speed: player.speed,
        playing: player.playing &&
            player.processingState != ProcessingState.completed,
        processingState: switch (player.processingState) {
          ProcessingState.idle => AudioProcessingState.idle,
          ProcessingState.loading => AudioProcessingState.loading,
          ProcessingState.buffering => AudioProcessingState.buffering,
          ProcessingState.ready => AudioProcessingState.ready,
          ProcessingState.completed => AudioProcessingState.completed,
        });
  }

  Future<void> stop() async {
    await player.stop();
    _controls?.unbind(this);
  }

  Future<void> dispose() async {
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _controls?.unbind(this);
    await player.dispose();
  }
}
