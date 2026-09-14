import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_voice/background_audio.dart';

void main() {
  test(
      'shared controls publish app metadata and dispatch clamped seek and transport actions',
      () async {
    final controls = NxStoredAudioRemoteControls();
    final owner = Object();
    var plays = 0;
    var pauses = 0;
    var stops = 0;
    Duration? seek;
    controls.bind(
        owner: owner,
        mediaId: 'tape-1',
        title: 'A quiet morning',
        album: 'NX Hypnosis',
        duration: const Duration(seconds: 60),
        speed: 1,
        onPlay: () async {
          plays++;
        },
        onPause: () async {
          pauses++;
        },
        onStop: () async {
          stops++;
        },
        onSeek: (v) async {
          seek = v;
        });
    expect(controls.mediaItem.value!.title, 'A quiet morning');
    expect(controls.mediaItem.value!.album, 'NX Hypnosis');
    await controls.play();
    await controls.pause();
    expect(plays, 1);
    expect(pauses, 1);
    controls.update(
        owner: owner,
        position: const Duration(seconds: 55),
        playing: true,
        speed: 1.25);
    await controls.fastForward();
    expect(seek, const Duration(seconds: 60));
    controls.update(owner: owner, position: const Duration(seconds: 5));
    await controls.rewind();
    expect(seek, Duration.zero);
    expect(controls.playbackState.value.controls, contains(MediaControl.pause));
    expect(controls.playbackState.value.speed, 1.25);
    controls.update(owner: owner, duration: const Duration(seconds: 90));
    expect(controls.mediaItem.value!.duration, const Duration(seconds: 90));
    await controls.stop();
    expect(stops, 1);
    controls.unbind(owner);
    expect(controls.mediaItem.value, isNull);
    expect(controls.playbackState.value.processingState,
        AudioProcessingState.idle);
    expect(controls.playbackState.value.playing, false);
  });

  test('previous player cannot update or clear the active player', () {
    final controls = NxStoredAudioRemoteControls();
    final previous = Object();
    final current = Object();
    void bind(Object owner, String id) => controls.bind(
        owner: owner,
        mediaId: id,
        duration: const Duration(seconds: 60),
        speed: 1,
        onPlay: () async {},
        onPause: () async {},
        onStop: () async {},
        onSeek: (_) async {});
    bind(previous, 'old');
    controls.update(
        owner: previous, position: const Duration(seconds: 30), playing: true);
    bind(current, 'new');
    expect(controls.playbackState.value.updatePosition, Duration.zero);
    controls.update(
        owner: previous, playing: true, duration: const Duration(seconds: 900));
    controls.unbind(previous);
    expect(controls.mediaItem.value!.id, 'new');
    expect(controls.playbackState.value.playing, false);
    expect(controls.mediaItem.value!.duration, const Duration(seconds: 60));
    controls.unbind(current);
  });
}
